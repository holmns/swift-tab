import { type HudItem, type SearchWeights } from "../shared/index.js";

export function computeTermScore(term: string, text: string): number {
  if (!term || !text) return 0;

  const contiguousIndex = text.indexOf(term);
  if (contiguousIndex !== -1) {
    let score = term.length * 120;
    score += Math.max(0, 600 - contiguousIndex * 40);
    if (contiguousIndex === 0) score += 160;
    return score;
  }

  let total = 0;
  let matched = 0;
  let consecutive = 0;
  let firstMatch = -1;

  for (let i = 0; i < text.length && matched < term.length; i += 1) {
    if (text[i] === term[matched]) {
      if (firstMatch === -1) firstMatch = i;
      consecutive += 1;
      matched += 1;
      total += 40 + consecutive * 12;
    } else {
      consecutive = 0;
    }
  }

  if (matched !== term.length) return 0;
  const proximity = firstMatch === -1 ? 0 : Math.max(0, 200 - firstMatch * 10);
  return total + proximity;
}

export function computeItemScore(
  item: HudItem,
  terms: string[],
  order: number,
  weights: SearchWeights
): number {
  const title = item.title?.toLowerCase() ?? "";
  const hostname = item.hostname?.toLowerCase() ?? "";
  const url = item.url?.toLowerCase() ?? "";

  const sources = [
    { text: title, weight: weights.title },
    { text: hostname, weight: weights.hostname },
    { text: url, weight: weights.url },
  ];

  let total = 0;
  for (const term of terms) {
    let best = 0;
    for (const { text, weight } of sources) {
      if (!text || weight <= 0) continue;
      const score = computeTermScore(term, text);
      if (score > best) {
        best = score * weight;
      }
    }
    if (best === 0) {
      return 0;
    }
    total += best;
  }

  if (item.pinned) total += 150;
  total += Math.max(0, 200 - order * 4);
  return total;
}
