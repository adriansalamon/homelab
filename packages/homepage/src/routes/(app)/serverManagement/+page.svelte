<script lang="ts">
	import { AppCardList, PageTitle } from "$lib/components/app";
	import {
		GrafanaAppCard,
		TraefikAppCard,
		UniFiNetworkAppCard,
		AutheliaAppCard,
		PrometheusAppCard,
		LLDAPAppCard,
		ConsulAppCard,
		NomadAppCard,
	} from "$lib/components/appCards";
	import type { PageServerData } from "./$types";

	interface Props {
		data: PageServerData;
		domain: string;
	}

	const { data }: Props = $props();
	const { domain, localDomain } = $derived(data);
</script>

<PageTitle showBackButton>Server Management</PageTitle>

<AppCardList title="Infrastructure">
	<ConsulAppCard domain={localDomain} />
	<NomadAppCard domain={localDomain} />
</AppCardList>

<AppCardList title="Observability">
	<GrafanaAppCard domain={localDomain} />
	<PrometheusAppCard domain={localDomain} />
</AppCardList>

<AppCardList title="Administration">
	<AutheliaAppCard {domain} />
	<LLDAPAppCard domain={localDomain} />
	<TraefikAppCard site="erebus" domain={localDomain} />
	<TraefikAppCard site="olympus" domain={localDomain} />
	<TraefikAppCard site="external" domain={localDomain} />
	<TraefikAppCard site="delphi" domain={localDomain} />
</AppCardList>
