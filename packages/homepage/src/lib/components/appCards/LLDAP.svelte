<script lang="ts">
	import { AppCard } from "../app";

	interface Props {
		domain?: string;
		notInList?: boolean;
		class?: string;
	}

	const { domain, notInList, class: className }: Props = $props();
</script>

<AppCard
	name="LLDAP"
	description="Lightweight LDAP server"
	gradientColours={["#0066cc", "#0088ff", "#00aaff"]}
	href="https://lldap.{domain}"
	class={className}
	{notInList}
></AppCard>
