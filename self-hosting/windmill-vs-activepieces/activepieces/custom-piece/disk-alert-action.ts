// Shape of a custom piece action (see the Activepieces "Building Pieces" docs).
// Build it inside a clone of the activepieces repo, not in this folder.
import { createAction, Property } from '@activepieces/pieces-framework';

export const diskAlert = createAction({
  name: 'disk_alert',
  displayName: 'Disk Alert',
  description: 'Flags a host whose disk usage crosses a threshold',
  props: {
    host: Property.ShortText({ displayName: 'Host', required: true }),
    usedPercent: Property.Number({ displayName: 'Used %', required: true }),
    threshold: Property.Number({ displayName: 'Threshold %', required: false, defaultValue: 85 }),
  },
  async run(context) {
    const { host, usedPercent, threshold } = context.propsValue;
    const limit = threshold ?? 85;
    return { host, alert: usedPercent >= limit };
  },
});
