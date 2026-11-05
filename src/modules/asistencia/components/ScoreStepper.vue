<script setup lang="ts">
import { ref, computed } from 'vue'

const props = defineProps<{
  max: number
  step?: number
  value: number | null
  disabled?: boolean
}>()

const emit = defineEmits<{ update: [value: number] }>()

const stepVal = computed(() => props.step ?? 5)

const quickValues = computed(() =>
  [0, 0.25, 0.5, 0.75, 1].map(f => Math.round(f * props.max))
)

const hasValue = computed(() => props.value !== null && props.value !== undefined)

let debounceTimer: ReturnType<typeof setTimeout> | null = null
function onStep(delta: number) {
  if (props.disabled) return
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    const cur = hasValue.value ? props.value! : 0
    const next = Math.max(0, Math.min(props.max, cur + delta))
    emit('update', next)
  }, 400)
}

function onQuick(v: number) {
  if (props.disabled) return
  emit('update', v)
}
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Value display + +/- -->
    <div class="flex items-center gap-2.5">
      <button
        type="button"
        :disabled="disabled"
        aria-label="`Restar ${stepVal}`"
        @click="onStep(-stepVal)"
        class="flex-shrink-0 flex items-center justify-center font-semibold border border-[#DCE1DD] bg-[#F4F6F4] text-[#16201B] rounded-[14px] transition-colors disabled:opacity-40 disabled:cursor-not-allowed
               w-[52px] h-[52px] text-[24px]
               md:w-12 md:h-12 md:text-[22px] md:rounded-xl"
      >−</button>

      <span class="flex-1 flex items-baseline justify-center gap-1">
        <span
          class="font-bold text-[34px] md:text-[32px] tabular-nums"
          :class="hasValue ? 'text-[#16201B]' : 'text-[#8A948E]'"
        >{{ hasValue ? value : '—' }}</span>
        <span class="text-[14px] text-[#5B6660]">/ {{ max }}</span>
      </span>

      <button
        type="button"
        :disabled="disabled"
        :aria-label="`Sumar ${stepVal}`"
        @click="onStep(stepVal)"
        class="flex-shrink-0 flex items-center justify-center font-semibold border border-[#DCE1DD] bg-[#F4F6F4] text-[#16201B] rounded-[14px] transition-colors disabled:opacity-40 disabled:cursor-not-allowed
               w-[52px] h-[52px] text-[24px]
               md:w-12 md:h-12 md:text-[22px] md:rounded-xl"
      >+</button>
    </div>

    <!-- Quick values -->
    <div class="grid gap-1.5" :style="{ gridTemplateColumns: `repeat(${quickValues.length}, minmax(0, 1fr))` }">
      <button
        v-for="q in quickValues"
        :key="q"
        type="button"
        :disabled="disabled"
        @click="onQuick(q)"
        class="font-semibold border transition-colors disabled:opacity-40 disabled:cursor-not-allowed
               h-10 rounded-[10px] text-[14px]
               md:h-[34px] md:rounded-[8px] md:text-[13px]"
        :class="value === q
          ? 'bg-[#0E7C59] text-white border-[#0E7C59]'
          : 'bg-white text-[#16201B] border-[#DCE1DD] hover:bg-[#F4F6F4]'"
      >{{ q }}</button>
    </div>
  </div>
</template>
