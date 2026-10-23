import { siteConfig } from "@/lib/site";

type AnalyticsWindow = Window & {
  gtag?: (command: string, eventName: string, parameters: Record<string, string | number>) => void;
};

export function trackEvent(
  eventName: string,
  parameters: Record<string, string | number> = {},
) {
  if (typeof window === "undefined") return;
  (window as AnalyticsWindow).gtag?.("event", eventName, {
    app_slug: siteConfig.appSlug,
    ...parameters,
  });
}
