class Rule {
  constructor() {
    this.projects = []
    for (let i = 0; i < 10; i++) {
      this.projects[i] = {
        vote: 0,
        area: 0,
      }
    }

    this.area = 0
  }

  result() {
    for (let i = 0; i < this.projects.length; i++) {
      const p = this.projects[i]
      const s = (p.area / this.area * 10000).toFixed(2)

      const r = [this.area, p.area, p.vote]
      this.vote(i)
      const d = Number((p.area - r[1]).toFixed(2))
      const da = ((p.area / this.area * 10000) - Number(s)).toFixed(2)
      this.area = r[0]
      p.area = r[1]
      p.vote = r[2]

      console.log(`P${i + 1}: \t${r[2]} votes  \t${s} areas  \t${da} dA  \t${d} d`)
    }
  }
}

class OldRules extends Rule {
  vote(i) {
    const index = Math.min(i, this.projects.length - 1)
    const p = this.projects[index]
    this.area += p.vote
    p.area += p.vote
    p.vote += 1
  }
}

class Rules2 extends Rule {
  constructor() {
    super()
    this.top = 1
  }

  vote(i) {
    const index = Math.min(i, this.projects.length - 1)
    const p = this.projects[index]

    const k = Math.max(Math.min(1, (p.area - 5000) / this.top), 0) * p.area / Math.max(1, this.area)
    const added = p.vote * (1 - k) ** 2

    this.area += added
    p.area += added
    p.vote += 1

    if (p.area > this.top) {
      this.top = p.area
    }
  }
}

function test(rules, votes, ps) {
  for (let k = 0; k < votes.length; k++) {
    const v = votes[k]
    const p = ps[k]
    for (let n = 0; n < v; n++) {
      let i = 0
      while (p[i] && Math.random() > p[i]) {
        i++
      }
      rules.forEach(r => {
        r.vote(i)
      })
    }
  }
  rules.forEach((r, i) => {
    console.log(`RULES ${i + 1} ===================================`)
    r.result()
    console.log('')
  })
}

const AVERAGE = [1/10, 1/9, 1/8, 1/7, 1/6, 1/5, 1/4, 1/3, 1/2]
const BSC = [2/7, 1.8/6, 1.6/5, 1.4/4, 1.2/3, 1/2, 1/2, 1/2, 1/2]
const AMASS = new Array(9).fill(1/2)
const AAMASS = [0.76, ...new Array(8).fill(0.6)]
const BAMASS = [0.9, ...new Array(8).fill(0.6)]
const ATTACK = [0.01, 0.9, ...new Array(7).fill(1/2)]

test([
  new OldRules(),
  new Rules2(),
], [40000, 2000], [AAMASS, ATTACK])
