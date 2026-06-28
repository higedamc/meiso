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
	case "list":
		return runTaskList(svc, args[1:])
	case "add":
		return runTaskAdd(svc, args[1:])
	case "done":
		return runTaskDone(svc, args[1:])
	case "shared":
		return runShared(ctx, svc, args[1:])
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
		return errors.New("usage: meiso login-local --secret <nsec-or-hex>")
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
	result, err := svc.Sync(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("sync completed: pulled %d, pushed %d\n", result.Pulled, result.Pushed)
	return nil
}

func runTaskList(svc *app.Service, args []string) error {
	flat := false
	filterList := ""
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--flat":
			flat = true
		default:
			if !strings.HasPrefix(args[i], "-") {
				filterList = args[i]
			}
		}
	}

	tasks, err := svc.ListTasks()
	if err != nil {
		return err
	}
	if len(tasks) == 0 {
		fmt.Println("no tasks")
		return nil
	}

	if flat {
		tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
		fmt.Fprintln(tw, "ID\tSTATUS\tDUE\tDIRTY\tLIST\tTITLE")
		for _, t := range tasks {
			fmt.Fprintf(tw, "%s\t%s\t%s\t%v\t%s\t%s\n",
				t.ID, t.Status, t.Due, t.Dirty, t.DisplayListName(), t.Title)
		}
		return tw.Flush()
	}

	printTree(os.Stdout, tasks, filterList)
	return nil
}

func runTaskAdd(svc *app.Service, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: meiso add --title <text> [--due today|tomorrow|someday] [--list <name>]")
	}
	title := ""
	due := model.DueToday
	listName := ""
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
		case "--list":
			if i+1 >= len(args) {
				return errors.New("--list value is required")
			}
			listName = args[i+1]
			i++
		}
	}
	task, err := svc.AddTask(title, due, listName)
	if err != nil {
		return err
	}
	list := task.DisplayListName()
	fmt.Printf("task added: %s [%s] %s\n", task.ID, list, task.Title)
	return nil
}

func runTaskDone(svc *app.Service, args []string) error {
	if len(args) < 2 || args[0] != "--id" {
		return errors.New("usage: meiso done --id <task-id>")
	}
	task, err := svc.DoneTask(args[1])
	if err != nil {
		return err
	}
	fmt.Printf("task completed: %s %s\n", task.ID, task.Title)
	return nil
}

func printUsage() {
	fmt.Println(`meiso commands:
  login
  login-local --secret <nsec-or-hex>
  status
  logout
  sync
  list [--flat] [<list-name>]
  add --title <text> [--due today|tomorrow|someday] [--list <name>]
  done --id <task-id>

  shared create --name <name>
  shared groups
  shared invite --group <id|name> --to <npub-or-hex>
  shared invites
  shared accept [<group-id>]
  shared add --group <id|name> --title <text> [--date today|tomorrow|YYYY-MM-DD]
  shared done --group <id|name> --id <task-id>
  shared reopen --group <id|name> --id <task-id>
  shared delete --group <id|name> --id <task-id>
  shared tasks --group <id|name>
  shared sync [--group <id|name>]`)
}

func runShared(ctx context.Context, svc *app.Service, args []string) error {
	if len(args) == 0 {
		return errors.New("usage: meiso shared <create|groups|invite|invites|accept|add|done|reopen|delete|tasks|sync> ...")
	}
	switch args[0] {
	case "create":
		return runSharedCreate(ctx, svc, args[1:])
	case "groups", "lists":
		return runSharedGroups(svc)
	case "invite":
		return runSharedInvite(ctx, svc, args[1:])
	case "invites":
		return runSharedInvites(ctx, svc)
	case "accept":
		return runSharedAccept(ctx, svc, args[1:])
	case "add":
		return runSharedAdd(ctx, svc, args[1:])
	case "done":
		return runSharedDone(ctx, svc, args[1:])
	case "reopen":
		return runSharedReopen(ctx, svc, args[1:])
	case "delete", "rm":
		return runSharedDelete(ctx, svc, args[1:])
	case "tasks", "list":
		return runSharedTasks(svc, args[1:])
	case "sync":
		return runSharedSync(ctx, svc, args[1:])
	default:
		return fmt.Errorf("unknown shared command: %s", args[0])
	}
}

// flagValue is a tiny helper to read `--key value` style flags.
func flagValue(args []string, key string) (string, bool) {
	for i := 0; i < len(args)-1; i++ {
		if args[i] == key {
			return args[i+1], true
		}
	}
	return "", false
}

func requireFlag(args []string, key string) (string, error) {
	v, ok := flagValue(args, key)
	if !ok || strings.TrimSpace(v) == "" {
		return "", fmt.Errorf("%s is required", key)
	}
	return v, nil
}

func runSharedCreate(ctx context.Context, svc *app.Service, args []string) error {
	name, err := requireFlag(args, "--name")
	if err != nil {
		return errors.New("usage: meiso shared create --name <name>")
	}
	group, err := svc.CreateSharedGroup(ctx, name)
	if err != nil {
		return err
	}
	fmt.Printf("shared group created: %s\n", group.Name)
	fmt.Printf("  group-id: %s\n", group.GroupID)
	fmt.Printf("  npub(hex): %s\n", group.GroupNpubHex)
	fmt.Println("  share it with: meiso shared invite --group " + group.GroupID + " --to <npub>")
	return nil
}

func runSharedGroups(svc *app.Service) error {
	groups, err := svc.ListSharedGroups()
	if err != nil {
		return err
	}
	if len(groups) == 0 {
		fmt.Println("no shared groups")
		return nil
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "GROUP-ID\tNAME\tEPOCH")
	for _, g := range groups {
		fmt.Fprintf(tw, "%s\t%s\t%d\n", g.GroupID, g.Name, g.KeyEpoch)
	}
	return tw.Flush()
}

func runSharedInvite(ctx context.Context, svc *app.Service, args []string) error {
	group, err := requireFlag(args, "--group")
	if err != nil {
		return errors.New("usage: meiso shared invite --group <id|name> --to <npub-or-hex>")
	}
	to, err := requireFlag(args, "--to")
	if err != nil {
		return errors.New("usage: meiso shared invite --group <id|name> --to <npub-or-hex>")
	}
	eventID, err := svc.SendSharedInvitation(ctx, group, to)
	if err != nil {
		return err
	}
	fmt.Printf("invitation sent: event=%s\n", shorten(eventID))
	return nil
}

func runSharedInvites(ctx context.Context, svc *app.Service) error {
	invites, err := svc.ListSharedInvitations(ctx)
	if err != nil {
		return err
	}
	if len(invites) == 0 {
		fmt.Println("no pending invitations")
		return nil
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "GROUP-ID\tNAME\tFROM\tWHEN")
	for _, inv := range invites {
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\n",
			inv.GroupID, inv.GroupName, shorten(inv.InviterPubkey), inv.CreatedAt.Format(time.RFC3339))
	}
	if err := tw.Flush(); err != nil {
		return err
	}
	fmt.Println("\naccept with: meiso shared accept [<group-id>]")
	return nil
}

func runSharedAccept(ctx context.Context, svc *app.Service, args []string) error {
	groupRef := ""
	if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
		groupRef = args[0]
	}
	accepted, err := svc.AcceptSharedInvitations(ctx, groupRef)
	if err != nil {
		return err
	}
	if len(accepted) == 0 {
		fmt.Println("no new invitations accepted")
		return nil
	}
	for _, g := range accepted {
		fmt.Printf("joined shared group: %s (%s)\n", g.Name, g.GroupID)
	}
	fmt.Println("run: meiso shared sync   to pull tasks")
	return nil
}

func runSharedAdd(ctx context.Context, svc *app.Service, args []string) error {
	group, err := requireFlag(args, "--group")
	if err != nil {
		return errors.New("usage: meiso shared add --group <id|name> --title <text> [--date today|tomorrow|YYYY-MM-DD]")
	}
	title, err := requireFlag(args, "--title")
	if err != nil {
		return errors.New("--title is required")
	}
	var date *string
	if raw, ok := flagValue(args, "--date"); ok {
		date, err = parseSharedDate(raw)
		if err != nil {
			return err
		}
	}
	task, err := svc.AddSharedTask(ctx, group, title, date)
	if err != nil {
		return err
	}
	fmt.Printf("shared task added: %s %s\n", task.ID, task.Title)
	return nil
}

func runSharedDone(ctx context.Context, svc *app.Service, args []string) error {
	group, err := requireFlag(args, "--group")
	if err != nil {
		return errors.New("usage: meiso shared done --group <id|name> --id <task-id>")
	}
	id, err := requireFlag(args, "--id")
	if err != nil {
		return errors.New("--id is required")
	}
	task, err := svc.DoneSharedTask(ctx, group, id)
	if err != nil {
		return err
	}
	fmt.Printf("shared task completed: %s %s\n", task.ID, task.Title)
	return nil
}

func runSharedReopen(ctx context.Context, svc *app.Service, args []string) error {
	group, err := requireFlag(args, "--group")
	if err != nil {
		return errors.New("usage: meiso shared reopen --group <id|name> --id <task-id>")
	}
	id, err := requireFlag(args, "--id")
	if err != nil {
		return errors.New("--id is required")
	}
	task, err := svc.ReopenSharedTask(ctx, group, id)
	if err != nil {
		return err
	}
	fmt.Printf("shared task reopened: %s %s\n", task.ID, task.Title)
	return nil
}

func runSharedDelete(ctx context.Context, svc *app.Service, args []string) error {
	group, err := requireFlag(args, "--group")
	if err != nil {
		return errors.New("usage: meiso shared delete --group <id|name> --id <task-id>")
	}
	id, err := requireFlag(args, "--id")
	if err != nil {
		return errors.New("--id is required")
	}
	task, err := svc.DeleteSharedTask(ctx, group, id)
	if err != nil {
		return err
	}
	fmt.Printf("shared task deleted: %s %s\n", task.ID, task.Title)
	return nil
}

func runSharedTasks(svc *app.Service, args []string) error {
	group, err := requireFlag(args, "--group")
	if err != nil {
		// allow positional group ref
		if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
			group = args[0]
		} else {
			return errors.New("usage: meiso shared tasks --group <id|name>")
		}
	}
	g, tasks, err := svc.ListSharedTasks(group)
	if err != nil {
		return err
	}
	fmt.Printf("# %s (%s)\n", g.Name, g.GroupID)
	if len(tasks) == 0 {
		fmt.Println("no tasks")
		return nil
	}
	tw := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "ID\tDONE\tDIRTY\tEDITOR\tTITLE")
	for _, t := range tasks {
		check := " "
		if t.Completed {
			check = "x"
		}
		fmt.Fprintf(tw, "%s\t[%s]\t%v\t%s\t%s\n",
			t.ID, check, t.Dirty, shorten(t.EditorPubkey), t.Title)
	}
	return tw.Flush()
}

func runSharedSync(ctx context.Context, svc *app.Service, args []string) error {
	if group, ok := flagValue(args, "--group"); ok {
		result, err := svc.SyncSharedGroup(ctx, group)
		if err != nil {
			return err
		}
		fmt.Printf("shared sync completed: pulled %d, pushed %d\n", result.Pulled, result.Pushed)
		return nil
	}
	result, err := svc.SyncAllSharedGroups(ctx)
	if err != nil {
		return err
	}
	fmt.Printf("shared sync completed (all groups): pulled %d, pushed %d\n", result.Pulled, result.Pushed)
	return nil
}

// parseSharedDate converts a date flag to an ISO datetime string the Flutter
// client can parse, or nil for "someday"/empty.
func parseSharedDate(raw string) (*string, error) {
	raw = strings.TrimSpace(strings.ToLower(raw))
	now := time.Now()
	midnight := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	switch raw {
	case "", "someday", "none":
		return nil, nil
	case "today":
		v := midnight.Format("2006-01-02T15:04:05")
		return &v, nil
	case "tomorrow":
		v := midnight.Add(24 * time.Hour).Format("2006-01-02T15:04:05")
		return &v, nil
	default:
		if t, err := time.Parse("2006-01-02", raw); err == nil {
			v := t.Format("2006-01-02T15:04:05")
			return &v, nil
		}
		return nil, fmt.Errorf("invalid --date: %s (use today|tomorrow|someday|YYYY-MM-DD)", raw)
	}
}

func shorten(v string) string {
	if len(v) <= 16 {
		return v
	}
	return v[:8] + "..." + v[len(v)-8:]
}
