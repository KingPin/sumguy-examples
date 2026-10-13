// Windmill script (Bun runtime). Windmill builds the input form from main()'s signature.
export async function main(host: string, used_percent: number, threshold: number = 85) {
  const alert = used_percent >= threshold;
  return { host, used_percent, threshold, alert, message: alert ? `${host} is at ${used_percent}% disk` : "ok" };
}
