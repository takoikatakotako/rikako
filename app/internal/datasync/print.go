package datasync

import (
	"fmt"
	"strings"
)

// PrintPlan outputs the plan in a terraform-like format.
func PrintPlan(plan *PlanResult) {
	sections := []struct {
		name  string
		diffs []DiffItem
	}{
		{"Images", plan.Images},
		{"Questions", plan.Questions},
		{"Workbooks", plan.Workbooks},
		{"Categories", plan.Categories},
	}

	for _, section := range sections {
		fmt.Printf("\n%s:\n", section.name)
		if len(section.diffs) == 0 {
			fmt.Println("  (no changes)")
			continue
		}

		for _, d := range section.diffs {
			color := colorForAction(d.Action)
			label := d.Label
			if label == "" && len(d.Details) > 0 {
				label = d.Details[0]
			}
			fmt.Printf("  %s%s %d%s", color, d.Action, d.ID, resetColor())
			if label != "" {
				fmt.Printf(" (%s)", label)
			}
			fmt.Println()

			if d.Action == ActionChange {
				for _, detail := range d.Details {
					fmt.Printf("      %s\n", detail)
				}
			}
		}
	}

	add, change, destroy := plan.Summary()
	fmt.Println()
	fmt.Printf("Plan: %s, %s, %s.\n",
		pluralize(add, "to add"),
		pluralize(change, "to change"),
		pluralize(destroy, "to destroy"),
	)
}

func colorForAction(a Action) string {
	switch a {
	case ActionAdd:
		return "\033[32m" // green
	case ActionChange:
		return "\033[33m" // yellow
	case ActionDelete:
		return "\033[31m" // red
	default:
		return ""
	}
}

func resetColor() string {
	return "\033[0m"
}

func pluralize(n int, suffix string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%d %s", n, suffix)
	return b.String()
}
