<script lang="ts">
	import { NavigationMenu } from "bits-ui";
</script>

<NavigationMenu.Root class="relative flex w-full justify-center border-accent text-accent border-b bg-primary">
	<NavigationMenu.List class="flex list-none items-center justify-center space-x-4 p-1">
		<NavigationMenu.Item>
			<NavigationMenu.Link
				class="inline-flex h-9 w-max items-center justify-center rounded-md px-4 py-2 text-sm font-medium transition-colors hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus:outline-none disabled:pointer-events-none disabled:opacity-50"
				href="/"
			>
				Jobs
			</NavigationMenu.Link>
		</NavigationMenu.Item>

		<NavigationMenu.Item>
			<NavigationMenu.Link
				class="inline-flex h-9 w-max items-center justify-center rounded-md px-4 py-2 text-sm font-medium transition-colors hover:text-accent-foreground focus:bg-accent focus:text-accent-foreground focus:outline-none disabled:pointer-events-none disabled:opacity-50"
				href="/resume"
			>
				Resume
			</NavigationMenu.Link>
		</NavigationMenu.Item>
	</NavigationMenu.List>
</NavigationMenu.Root>
