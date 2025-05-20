<script lang="ts">
	import { NavigationMenu } from "bits-ui";
	import { tv } from "tailwind-variants"; // Import tv

	// Define nav link variants using tv
	const navLinkVariants = tv({
		base: "font-medium text-white hover:underline hover:underline-offset-4 transition-colors", // Base styles
		variants: {
			active: {
				true: "underline underline-offset-4", // Styles when active
				false: "", // No additional styles when not active
			},
		},
	});

	export let currentPath: string | undefined = undefined;

	// Function to determine if a nav item is active
	function isActive(path: string): boolean {
		// If no currentPath is provided, default to Jobs being active
		if (!currentPath) {
			return path === "/";
		}
		return currentPath === path;
	}

	// Log when currentPath changes
	$: {
		if (currentPath) {
			console.log('currentPath changed:', currentPath);
			console.log('currentPath type:', typeof currentPath);
			console.log('currentPath length:', currentPath.length);
			console.log('currentPath chars:', Array.from(currentPath).map(c => c.charCodeAt(0)));
		} else {
			console.log('currentPath is undefined');
		}
	}
</script>

<NavigationMenu.Root
	class="relative flex w-full justify-center py-1 text-white border-b bg-primary"
>
	<NavigationMenu.List
		class="flex list-none items-center justify-center space-x-4 p-1"
	>
		<NavigationMenu.Item>
			<a
				class={navLinkVariants({ active: isActive("/") })}
				href="/"
				data-phx-link="patch"
				data-phx-link-state="push"
			>
				Jobs
			</a>
		</NavigationMenu.Item>

		<NavigationMenu.Item>
			<a
				class={navLinkVariants({ active: isActive("/resume") })}
				href="/resume"
				data-phx-link="patch"
				data-phx-link-state="push"
			>
				Resume
			</a>
		</NavigationMenu.Item>
	</NavigationMenu.List>
</NavigationMenu.Root>
