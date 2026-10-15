<script>
export default {
  props: { labelledBy: { type: String, required: true } },
  emits: ['close'],
  mounted() {
    this.previousFocus = document.activeElement
    this.previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    this.$refs.dialog.querySelector('input, button, select, [tabindex="0"]')?.focus()
  },
  beforeUnmount() {
    document.body.style.overflow = this.previousOverflow
    this.previousFocus?.focus()
  },
  methods: {
    handleKey(event) {
      if (event.key === 'Escape') {
        event.preventDefault()
        this.$emit('close')
      }
      if (event.key !== 'Tab') return
      const elements = [...this.$refs.dialog.querySelectorAll('button, input, select, a[href], [tabindex="0"]')].filter(element => !element.disabled)
      const first = elements[0]
      const last = elements.at(-1)
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last?.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first?.focus()
      }
    }
  }
}
</script>
<template>
  <Teleport to="body">
    <div class="dialog-backdrop" @click.self="$emit('close')" @keydown="handleKey">
      <div ref="dialog" class="dialog-panel" role="dialog" aria-modal="true" :aria-labelledby="labelledBy">
        <slot />
      </div>
    </div>
  </Teleport>
</template>
