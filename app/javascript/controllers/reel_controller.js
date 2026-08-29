import { Controller } from "@hotwired/stimulus"

// One reel, entered as a column of stops.
//
// A reel is a vertical strip and the window shows consecutive stops stacked, so the
// thing on screen should look like the thing being described. Typing straight down a
// column without reaching for the mouse is the point; everything here serves that.
export default class extends Controller {
  static targets = ["rows", "row", "input", "stops", "counts", "template"]
  static values = { position: Number }

  connect() {
    this.renumber()
  }

  // Enter goes down the column, adding a stop at the bottom so a reel grows as it is
  // typed. Backspace on an empty stop removes it, which is how a row typed by mistake
  // is undone without leaving the keyboard.
  key(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.moveDown(event.target)
    } else if (event.key === "Backspace" && event.target.value === "") {
      event.preventDefault()
      this.remove(event.target.closest("[data-reel-target='row']"), { focusPrevious: true })
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.focusOffset(event.target, 1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.focusOffset(event.target, -1)
    }
  }

  // Pasting a column from a spreadsheet is how strips actually arrive, so it fills
  // downwards from wherever it lands rather than dropping everything into one stop.
  paste(event) {
    const text = event.clipboardData?.getData("text") ?? ""
    const codes = text.split(/[\s,]+/).filter(Boolean)
    if (codes.length < 2) return

    event.preventDefault()

    // A row is only added when there is another code to put in it: stepping past the
    // last one would leave a blank stop the paste did not ask for.
    let input = event.target
    codes.forEach((code, index) => {
      input.value = code
      if (index < codes.length - 1) input = this.inputBelow(input) ?? this.addRow().querySelector("input")
    })

    this.renumber()
  }

  addStop(event) {
    event?.preventDefault()
    this.addRow().querySelector("input").focus()
    this.renumber()
  }

  removeRow(event) {
    event.preventDefault()
    this.remove(event.target.closest("[data-reel-target='row']"))
  }

  recount() {
    const codes = this.inputTargets.map((input) => input.value.trim()).filter(Boolean)

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
      .join("  ·  ")
  }

  moveDown(input) {
    const below = this.inputBelow(input)
    if (below) below.focus()
    else this.addStop()
  }

  focusOffset(input, offset) {
    const next = this.inputTargets[this.inputTargets.indexOf(input) + offset]
    if (next) next.focus()
  }

  inputBelow(input) {
    return this.inputTargets[this.inputTargets.indexOf(input) + 1]
  }

  addRow() {
    this.rowsTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    return this.rowsTarget.lastElementChild
  }

  remove(row, { focusPrevious = false } = {}) {
    if (!row) return

    // A reel with no stops at all cannot be typed back into, so the last row stays and
    // is emptied instead. An empty strip is saved by clearing it, not by deleting it.
    const previous = row.previousElementSibling
    if (this.rowTargets.length === 1) row.querySelector("input").value = ""
    else row.remove()

    if (focusPrevious && previous) previous.querySelector("input").focus()
    this.renumber()
  }

  // Stop numbers are the reel's own, not shared across reels: reels stop
  // independently, so stop 7 of one has nothing to do with stop 7 of another.
  renumber() {
    this.rowTargets.forEach((row, index) => {
      const stop = index + 1
      row.querySelector("[data-stop-number]").textContent = stop
      row.querySelector("input").setAttribute("aria-label", `Reel ${this.positionValue} stop ${stop}`)
      row.querySelector("button").setAttribute("aria-label", `Remove reel ${this.positionValue} stop ${stop}`)
    })

    this.recount()
  }
}
