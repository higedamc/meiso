package cli

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/higedamc/meiso/cui/internal/model"
)

const (
	treeEdge   = "├── "
	treeLast   = "└── "
	treePipe   = "│   "
	treeIndent = "    "
)

type listGroup struct {
	name  string
	key   string
	tasks []model.Task
}

func printTree(w io.Writer, tasks []model.Task, filterList string) {
	groups := groupByList(tasks)

	if filterList != "" {
		filtered := make([]listGroup, 0)
		lower := strings.ToLower(filterList)
		for _, g := range groups {
			if strings.ToLower(g.name) == lower || strings.ToLower(g.key) == lower {
				filtered = append(filtered, g)
			}
		}
		groups = filtered
	}

	if len(groups) == 0 {
		fmt.Fprintln(w, "no tasks")
		return
	}

	fmt.Fprintln(w, "Meiso")
	for gi, g := range groups {
		isLastGroup := gi == len(groups)-1
		groupPrefix := treeEdge
		if isLastGroup {
			groupPrefix = treeLast
		}
		fmt.Fprintf(w, "%s%s\n", groupPrefix, g.name)

		roots, children := splitRootsAndChildren(g.tasks)
		printTaskNodes(w, roots, children, isLastGroup, 1)
	}
}

func groupByList(tasks []model.Task) []listGroup {
	m := make(map[string]*listGroup)
	var order []string

	for _, t := range tasks {
		key := t.ListKey()
		if _, ok := m[key]; !ok {
			m[key] = &listGroup{
				key:  key,
				name: t.DisplayListName(),
			}
			order = append(order, key)
		}
		m[key].tasks = append(m[key].tasks, t)
	}

	// "default" always comes first
	sort.SliceStable(order, func(i, j int) bool {
		if order[i] == "default" {
			return true
		}
		if order[j] == "default" {
			return false
		}
		return m[order[i]].name < m[order[j]].name
	})

	out := make([]listGroup, 0, len(order))
	for _, key := range order {
		g := m[key]
		sort.SliceStable(g.tasks, func(i, j int) bool {
			return g.tasks[i].CreatedAt.Before(g.tasks[j].CreatedAt)
		})
		out = append(out, *g)
	}
	return out
}

func splitRootsAndChildren(tasks []model.Task) ([]model.Task, map[string][]model.Task) {
	children := make(map[string][]model.Task)
	var roots []model.Task
	for _, t := range tasks {
		if t.ParentTaskID != nil && *t.ParentTaskID != "" {
			children[*t.ParentTaskID] = append(children[*t.ParentTaskID], t)
		} else {
			roots = append(roots, t)
		}
	}
	return roots, children
}

func printTaskNodes(w io.Writer, nodes []model.Task, children map[string][]model.Task, parentIsLast bool, depth int) {
	for i, t := range nodes {
		isLast := i == len(nodes)-1
		connector := treeEdge
		if isLast {
			connector = treeLast
		}

		prefix := buildPrefix(parentIsLast, depth)

		check := "[ ]"
		if t.Status == model.TaskStatusDone {
			check = "[x]"
		}

		due := ""
		if t.Due != "" {
			due = fmt.Sprintf("  (%s)", t.Due)
		}

		fmt.Fprintf(w, "%s%s%s %s%s\n", prefix, connector, check, t.Title, due)

		if subs, ok := children[t.ID]; ok {
			subParentIsLast := parentIsLast && isLast
			if !isLast {
				subParentIsLast = false
			}
			printTaskNodes(w, subs, children, subParentIsLast, depth+1)
		}
	}
}

func buildPrefix(parentIsLast bool, depth int) string {
	if depth <= 0 {
		return ""
	}
	var sb strings.Builder
	for i := 0; i < depth; i++ {
		if i == depth-1 {
			if parentIsLast {
				sb.WriteString(treeIndent)
			} else {
				sb.WriteString(treePipe)
			}
		} else {
			sb.WriteString(treePipe)
		}
	}
	return sb.String()
}
