<script lang="ts">
import type { PageData } from './$types.js'

type Props = {
  data: PageData
}

const { data }: Props = $props()

const { userCount } = data
</script>

<p>We have {userCount} users.</p>
