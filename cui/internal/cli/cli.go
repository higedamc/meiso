package cli

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"text/tabwriter"
	"time"

	"github.com/higedamc/meiso/cui/internal/app"
	"github.com/higedamc/meiso/cui/internal/model"
)

func Run(ctx context.Context, svc *app.Service, args []string) error {
	if len(args) == 0 {
		printUsage()
		return nil
	}
	switch args[0] {
	case "login":
		return runLogin(ctx, svc)
	case "login-local":
		return runLoginLocal(svc, args[1:])
	case "status":
		return runStatus(svc)
	case "logout":
		return runLogout(svc)
	case "sync":
		return runSync(ctx, svc)
	case "task":
		return runTask(svc, args[1:])
	default:
		return fmt.Errorf("unknown command: %s", args[0])
	}
}

func runLogin(ctx context.Context, svc *app.Service) error {
	session, err := svc.Login(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("login completed: pubkey=%s expires=%s\n", shorten(session.PubKey), session.ExpiresAt.Format(time.RFC3339))
	return nil
}

func runLoginLocal(svc *app.Service, args []string) error {
	if len(args) < 2 || args[0] != "--secret" {
		return errors.New("usage: meiso-cui login-local --secret <nsec-or-hex>")
	}
	session, err := svc.LoginLocal(args[1])
	if err != nil {
		return err
	}
	fmt.Printf("local login completed: pubkey=%s\n", shorten(session.PubKey))
	return nil
}

func runStatus(svc *app.Service) error {
	session, valid, err := svc.SessionStatus()
	if err != nil {
		return err
	}
	if session == nil {
		fmt.Println("status: not logged in")
		return nil
	}
	fmt.Printf("status: logged in (%s)\n", session.SignerName)
	fmt.Printf("pubkey: %s\n", session.PubKey)
	if len(session.RelayURLs) > 0 {
		fmt.Printf("relays: %s\n", strings.Join(session.RelayURLs, ", "))
	} else {
		fmt.Printf("relay: %s\n", session.RelayURL)
	}
	fmt.Printf("expires: %s (valid=%v)\n", session.ExpiresAt.Format(time.RFC3339), valid)
	fmt.Printf("last_success: %s\n", session.LastSuccessAt.Format(time.RFC3339))
	fmt.Printf("failure_count: %d\n", session.FailureCount)
	return nil
}

func runLogout(svc *app.Service) error {
	if err := svc.Logout(); err != nil {
		return err
	}
	fmt.Println("logged out")
	return nil
}

func runSync(ctx context.Context, svc *app.Service) error {
	n, err := svc.Sync(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("sync completed: %d task(s)\n", n)
	return nil
}

func runTask(svc *app.Service, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: meiso-cui task [list|add|done]")
	}
	switch args[0] {
	case "list":
		return runTaskList(svc)
	case "add":
		return runTaskAdd(svc, args[1:])
	case "done":
		return runTaskDone(svc, args[1:])
	default:
		return fmt.Errorf("unknown task subcommand: %s", args[0])
	}
}

func runTaskList(svc *app.Service) error {
	tasks, err := svc.ListTasks()
	if err != nil {
		return err
	}
	if len(tasks) == 0 {
		fmt.Println("no tasks")
		return nil
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "ID\tSTATUS\tDUE\tDIRTY\tTITLE")
	for _, t := range tasks {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%v\t%s\n", t.ID, t.Status, t.Due, t.Dirty, t.Title)
	}
	return tw.Flush()
}

func runTaskAdd(svc *app.Service, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: meiso-cui task add --title <text> [--due today|tomorrow|someday]")
	}
	title := ""
	due := model.DueToday
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--title":
			if i+1 >= len(args) {
				return errors.New("--title value is required")
			}
			title = args[i+1]
			i++
		case "--due":
			if i+1 >= len(args) {
				return errors.New("--due value is required")
			}
			switch strings.ToLower(args[i+1]) {
			case "today":
				due = model.DueToday
			case "tomorrow":
				due = model.DueTomorrow
			case "someday":
				due = model.DueSomeday
			default:
				return fmt.Errorf("invalid due: %s", args[i+1])
			}
			i++
		}
	}
	task, err := svc.AddTask(title, due)
	if err != nil {
		return err
	}
	fmt.Printf("task added: %s %s\n", task.ID, task.Title)
	return nil
}

func runTaskDone(svc *app.Service, args []string) error {
	if len(args) < 2 || args[0] != "--id" {
		return errors.New("usage: meiso-cui task done --id <task-id>")
	}
	task, err := svc.DoneTask(args[1])
	if err != nil {
		return err
	}
	fmt.Printf("task completed: %s %s\n", task.ID, task.Title)
	return nil
}

func printUsage() {
	fmt.Println(`meiso-cui commands:
  login
  login-local --secret <nsec-or-hex>
  status
  logout
  sync
  task list
  task add --title <text> [--due today|tomorrow|someday]
  task done --id <task-id>`)
}

func shorten(v string) string {
	if len(v) <= 16 {
		return v
	}
	return v[:8] + "..." + v[len(v)-8:]
}
