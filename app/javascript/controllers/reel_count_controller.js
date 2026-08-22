import { Controller } from "@hotwired/stimulus"

// Counts the stops on a reel as it is typed. The per-symbol frequency is what drives
// RTP intuition, even though order is what actually determines the outcome.
export default class extends Controller {
  static targets = ["input", "stops", "counts"]

  connect() {
    this.recount()
  }

  recount() {
    const codes = this.inputTarget.value.split(/[\s,]+/).filter(Boolean)

    this.stopsTarget.textContent = codes.length === 1 ? "1 stop" : `${codes.length} stops`

    const tally = new Map()
    for (const code of codes) {
      const key = code.toUpperCase()
      tally.set(key, (tally.get(key) || 0) + 1)
    }

    this.countsTarget.textContent = [...tally]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([code, count]) => `${code} ${count}`)
      // A visible separator: HTML collapses runs of whitespace, so spacing alone
      // leaves the pairs running into one another.
      .join("  \u00b7  ")
  }
}
