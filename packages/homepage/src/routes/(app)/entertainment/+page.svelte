<script lang="ts">
	import type { PageServerData } from "./$types";
	import { JellyfinRecentsCarousel } from "$lib/components/entertainment";
	import {
		SnapcastAppCard,
		JellyfinAppCard,
		ProwlarrAppCard,
		DelugeAppCard,
		RadarrAppCard,
		SonarrAppCard,
	} from "$lib/components/appCards";
	import { AppCardList, AppCardListTitle, PageTitle } from "$lib/components/app";

	interface Props {
		data: PageServerData;
	}

	const { data }: Props = $props();
	const { domain, localDomain } = $derived(data);
</script>

<PageTitle showBackButton>Entertainment</PageTitle>

<AppCardList title="Media">
	<JellyfinAppCard {domain} />
	<SnapcastAppCard domain={localDomain} />
</AppCardList>

<JellyfinRecentsCarousel {domain} />

<AppCardList title="Media Fetchers" titleClass="mt-6">
	<ProwlarrAppCard domain={localDomain} />
	<RadarrAppCard domain={localDomain} />
	<SonarrAppCard domain={localDomain} />
</AppCardList>

<AppCardList title="Media Downloaders" titleClass="mt-6">
	<DelugeAppCard domain={localDomain} />
</AppCardList>
