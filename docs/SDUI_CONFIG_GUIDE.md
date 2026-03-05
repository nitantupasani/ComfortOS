# ComfortOS — SDUI Dashboard Config Guide

> **Server-Driven UI (SDUI)** lets you define each building's dashboard layout
> as a JSON tree. The mobile app renders the tree recursively — no app update
> required when you redesign a dashboard.

---

## Table of Contents

1. [How It Works](#1-how-it-works)
2. [Config Structure](#2-config-structure)
3. [Widget Type Reference](#3-widget-type-reference)
   - [Layout Widgets](#31-layout-widgets)
   - [Dashboard Widgets](#32-dashboard-widgets)
   - [Extended Convenience Widgets](#33-extended-convenience-widgets)
4. [Icon Reference](#4-icon-reference)
5. [Color Reference](#5-color-reference)
6. [Full Example Configs](#6-full-example-configs)
   - [Corporate HQ Dashboard](#61-corporate-hq--classic-comfort-metrics)
   - [Research Lab Dashboard](#62-research-lab--energy--sustainability)
   - [Co-Working Hub Dashboard](#63-co-working-hub--occupancy--scheduling)
   - [Wellness Centre Dashboard](#64-wellness-centre--health--air-quality)
7. [Best Practices](#7-best-practices)
8. [Location Form Config](#8-location-form-config)
9. [Populating Dashboard Fields from 3rd-Party APIs](#9-populating-dashboard-fields-from-3rd-party-apis)
   - [Built-in Example: Real-Time Weather](#91-built-in-example-real-time-weather-via-open-meteo)
   - [Extending to Other Data Sources](#92-extending-the-pattern-to-other-data-sources)
   - [Implementation Approach](#93-implementation-approach)
   - [Free APIs for Building Dashboards](#94-free-apis-suitable-for-building-dashboards)

---

## 1. How It Works

```
Server / Backend                    ComfortOS App
┌────────────────┐                 ┌──────────────────────────┐
│ getDashboard() │ ──JSON tree──▸  │ SDUIRenderer             │
│   returns a    │                 │  └─ SDUIWidgetRegistry    │
│   config map   │                 │      (looks up 'type',   │
└────────────────┘                 │       builds Flutter      │
                                   │       widget)             │
                                   └──────────────────────────┘
```

1. The backend returns a `Map<String, dynamic>` describing the dashboard.
2. `SDUIRenderer` receives the map, reads `type`, and calls the matching
   builder from `SDUIWidgetRegistry`.
3. If a node has `children`, the renderer recurses into each one.
4. If a building returns `null`, the app uses `DefaultDashboard.config`.

Live weather data is injected into any `weather_badge` node automatically.

---

## 2. Config Structure

Every config is a **tree of nodes**. Each node is a JSON object with at least
a `type` key:

```json
{
  "type": "widget_type_name",
  "property1": "value",
  "property2": 42,
  "children": [ ... ]
}
```

The root node is almost always a `column` with `crossAxisAlignment: "stretch"`
so child widgets fill the width of the screen:

```json
{
  "type": "column",
  "crossAxisAlignment": "stretch",
  "children": [
    { "type": "weather_badge", ... },
    { "type": "spacer", "height": 16 },
    { "type": "metric_tile", ... }
  ]
}
```

---

## 3. Widget Type Reference

### 3.1 Layout Widgets

These control how children are arranged. They do not render visible content
themselves.

#### `column`

Vertical stack of children.

| Property             | Type     | Default    | Description                                      |
|----------------------|----------|------------|--------------------------------------------------|
| `crossAxisAlignment` | `String` | `"center"` | `start`, `end`, `center`, `stretch`              |
| `mainAxisAlignment`  | `String` | `"start"`  | `start`, `end`, `spaceAround`, `spaceBetween`, `spaceEvenly` |
| `children`           | `List`   | `[]`       | Array of child node objects                      |

```json
{
  "type": "column",
  "crossAxisAlignment": "stretch",
  "children": [ ... ]
}
```

#### `row`

Horizontal stack of children.

| Property             | Type     | Default    | Description |
|----------------------|----------|------------|-------------|
| `mainAxisAlignment`  | `String` | `"start"`  | Same options as column |
| `crossAxisAlignment` | `String` | `"center"` | Same options as column |
| `children`           | `List`   | `[]`       | Array of child node objects |

```json
{
  "type": "row",
  "mainAxisAlignment": "spaceBetween",
  "children": [
    { "type": "text", "text": "Left" },
    { "type": "text", "text": "Right" }
  ]
}
```

#### `grid`

N-column responsive grid. Wraps children into rows automatically.

| Property  | Type  | Default | Description                 |
|-----------|-------|---------|-----------------------------|
| `columns` | `int` | `3`     | Number of columns per row   |
| `spacing` | `num` | `10`    | Spacing between items (px)  |
| `children`| `List`| `[]`    | Child nodes to distribute   |

```json
{
  "type": "grid",
  "columns": 3,
  "spacing": 10,
  "children": [
    { "type": "metric_tile", "icon": "thermostat", "value": "22", "unit": "°C", "label": "Temp" },
    { "type": "metric_tile", "icon": "co2", "value": "420", "unit": "ppm", "label": "CO2" },
    { "type": "metric_tile", "icon": "volume_up", "value": "38", "unit": "dB", "label": "Noise" }
  ]
}
```

#### `spacer`

Adds vertical whitespace.

| Property | Type  | Default | Description       |
|----------|-------|---------|-------------------|
| `height` | `num` | `16`    | Height in pixels  |

```json
{ "type": "spacer", "height": 20 }
```

#### `padding`

Wraps children in uniform padding.

| Property   | Type  | Default | Description     |
|------------|-------|---------|-----------------|
| `all`      | `num` | `16`    | Padding (px)    |
| `children` | `List`| `[]`    | Child nodes     |

#### `container`

Generic container (8px internal padding), wraps children.

#### `sizedBox`

Explicit size box.

| Property | Type  | Description |
|----------|-------|-------------|
| `width`  | `num` | Width (px)  |
| `height` | `num` | Height (px) |

#### `divider`

A horizontal line separator. No properties needed.

```json
{ "type": "divider" }
```

---

### 3.2 Dashboard Widgets

These are the primary building blocks of comfort dashboards.

#### `weather_badge`

Compact pill showing outdoor weather. Live data is injected automatically.

| Property | Type     | Default      | Description                     |
|----------|----------|--------------|---------------------------------|
| `temp`   | `String` | `"--"`       | Temperature value               |
| `unit`   | `String` | `"°C"`       | Unit string after temp          |
| `label`  | `String` | `"Outside"`  | Location label (auto-set to city name) |
| `icon`   | `String` | `"wb_sunny"` | Icon name (see §4)              |

```json
{
  "type": "weather_badge",
  "temp": "15",
  "unit": "°C",
  "label": "Outside",
  "icon": "wb_sunny"
}
```

#### `metric_tile`

Compact card showing a single metric with icon, value, unit, and label.
Best used inside a `grid` with 2–3 columns.

| Property | Type     | Default  | Description         |
|----------|----------|----------|---------------------|
| `icon`   | `String` | `"info"` | Icon name           |
| `value`  | `String` | `"--"`   | Main numeric value  |
| `unit`   | `String` | `""`     | Unit suffix         |
| `label`  | `String` | `""`     | Caption below value |

```json
{
  "type": "metric_tile",
  "icon": "thermostat",
  "value": "22.5",
  "unit": "°C",
  "label": "Temp"
}
```

#### `trend_card`

Area chart card with optional change badge. Shows time-series data.

| Property   | Type       | Default   | Description                        |
|------------|------------|-----------|------------------------------------|
| `title`    | `String`   | `"Trend"` | Card title                         |
| `subtitle` | `String?`  | —         | Subtitle below title               |
| `change`   | `String?`  | —         | Badge text, e.g. `"+1.2°"`        |
| `data`     | `List<num>`| `[]`      | Y-axis values (at least 2 points) |
| `labels`   | `List<String>` | `[]`  | X-axis labels                      |

```json
{
  "type": "trend_card",
  "title": "Temperature Trend",
  "subtitle": "Last 24 hours",
  "change": "+1.2°",
  "data": [15, 15, 18, 22, 25, 22.5],
  "labels": ["12AM", "6AM", "12PM", "6PM"]
}
```

#### `alert_banner`

Colored alert/info banner with icon, title, and subtitle.

| Property   | Type      | Default  | Description                            |
|------------|-----------|----------|----------------------------------------|
| `icon`     | `String`  | `"info"` | Icon name                              |
| `title`    | `String`  | `""`     | Bold title text                        |
| `subtitle` | `String?` | —        | Description text                       |
| `color`    | `String`  | `"blue"` | Banner color: see §5                   |

```json
{
  "type": "alert_banner",
  "icon": "thermostat",
  "title": "Building is Warming Up",
  "subtitle": "HVAC system is adjusting to reach target temperature.",
  "color": "orange"
}
```

#### `room_selector`

Legacy node — now hidden (the room is displayed in the top bar). Include it
for backwards compatibility; the renderer renders an empty widget.

```json
{ "type": "room_selector", "room": "Conference Room A" }
```

#### `primary_action`

Full-width prominent button.

| Property | Type      | Default    | Description |
|----------|-----------|------------|-------------|
| `label`  | `String`  | `"Action"` | Button text |
| `icon`   | `String?` | —          | Optional leading icon |

---

### 3.3 Extended Convenience Widgets

These complement the core dashboard widgets for richer layouts.

#### `section_header`

Bold section title with optional icon and subtitle. Use before a group of
related widgets.

| Property   | Type      | Default | Description          |
|------------|-----------|---------|----------------------|
| `title`    | `String`  | `""`    | Header text          |
| `subtitle` | `String?` | —       | Description below    |
| `icon`     | `String?` | —       | Optional icon prefix |

```json
{ "type": "section_header", "title": "Energy Usage", "icon": "bolt" }
```

#### `stat_row`

Horizontal label-value row — great for key-value lists.

| Property | Type      | Default | Description                |
|----------|-----------|---------|----------------------------|
| `label`  | `String`  | `""`    | Left-aligned label         |
| `value`  | `String`  | `""`    | Right-aligned bold value   |
| `icon`   | `String?` | —       | Optional leading icon      |
| `color`  | `String?` | —       | Color for icon and value   |

```json
{
  "type": "stat_row",
  "icon": "thermostat",
  "label": "Temperature",
  "value": "24.1 °C"
}
```

#### `progress_bar`

Horizontal progress bar with label, numeric value, and color.

| Property | Type      | Default | Description                |
|----------|-----------|---------|----------------------------|
| `label`  | `String`  | `""`    | Description text           |
| `value`  | `num`     | `0`     | Current value              |
| `max`    | `num`     | `100`   | Maximum value (100%)       |
| `unit`   | `String`  | `""`    | Unit suffix                |
| `color`  | `String?` | primary | Bar color (see §5)         |

```json
{
  "type": "progress_bar",
  "label": "Renewable share",
  "value": 26.2,
  "max": 100,
  "unit": "%",
  "color": "green"
}
```

#### `kpi_card`

Standalone big-number card with optional trend arrow.

| Property | Type      | Default   | Description                     |
|----------|-----------|-----------|---------------------------------|
| `title`  | `String`  | `""`      | Metric name                     |
| `value`  | `String`  | `"--"`    | Big number                      |
| `unit`   | `String`  | `""`      | Unit suffix                     |
| `trend`  | `String?` | —         | `"up"` (green ↑) or `"down"` (red ↓) |
| `color`  | `String?` | primary   | Value color                     |

```json
{
  "type": "kpi_card",
  "title": "Solar Generation",
  "value": "42",
  "unit": " kW",
  "trend": "up",
  "color": "green"
}
```

#### `info_row`

Key-value line with icon, suited for detail/building-info sections.

| Property | Type      | Default | Description           |
|----------|-----------|---------|-----------------------|
| `label`  | `String`  | `""`    | Left label            |
| `value`  | `String`  | `""`    | Right-aligned value   |
| `icon`   | `String?` | —       | Optional leading icon |

```json
{
  "type": "info_row",
  "icon": "cleaning_services",
  "label": "Last cleaned",
  "value": "08:30 AM today"
}
```

#### `badge_row`

Horizontal row of coloured badge chips with icons.

| Property | Type   | Default | Description                         |
|----------|--------|---------|-------------------------------------|
| `badges` | `List` | `[]`    | Array of badge objects (see below)  |

Each badge object:

| Property | Type      | Default | Description     |
|----------|-----------|---------|-----------------|
| `label`  | `String`  | `""`    | Badge text      |
| `icon`   | `String?` | —       | Optional icon   |
| `color`  | `String?` | `"blue"`| Badge color     |

```json
{
  "type": "badge_row",
  "badges": [
    { "label": "LEED Platinum", "icon": "verified", "color": "green" },
    { "label": "Net Zero", "icon": "eco", "color": "teal" }
  ]
}
```

#### `occupancy_indicator`

Circular progress ring with percentage and auto-generated utilisation label.

| Property  | Type      | Default       | Description                  |
|-----------|-----------|---------------|------------------------------|
| `label`   | `String`  | `"Occupancy"` | Label text                   |
| `percent` | `num`     | `0`           | 0‒100                        |
| `color`   | `String?` | primary       | Ring color                   |

```json
{
  "type": "occupancy_indicator",
  "label": "Space Occupancy",
  "percent": 73,
  "color": "orange"
}
```

#### `schedule_item`

Timeline-style item for event schedules.

| Property   | Type      | Default   | Description                    |
|------------|-----------|-----------|--------------------------------|
| `time`     | `String`  | `""`      | Time string, e.g. `"09:00"`   |
| `title`    | `String`  | `""`      | Event title                    |
| `subtitle` | `String?` | —         | Location / description         |
| `icon`     | `String`  | `"event"` | Trailing icon                  |
| `active`   | `bool`    | `false`   | Highlight as current/active    |

```json
{
  "type": "schedule_item",
  "time": "09:00",
  "title": "Morning standup",
  "subtitle": "Hot Desk Zone A",
  "icon": "people",
  "active": true
}
```

#### `image_banner`

Gradient-coloured hero banner with title, subtitle, and icon.

| Property   | Type      | Default  | Description              |
|------------|-----------|----------|--------------------------|
| `title`    | `String`  | `""`     | Banner heading           |
| `subtitle` | `String?` | —        | Sub-heading              |
| `icon`     | `String`  | `"info"` | Large icon on right side |
| `color`    | `String`  | `"blue"` | Gradient base color      |

```json
{
  "type": "image_banner",
  "title": "Sustainability Dashboard",
  "subtitle": "Real-time energy & environment",
  "icon": "eco",
  "color": "green"
}
```

---

### Basic Primitives

These are always available for fine-grained layouts:

| Type       | Key Properties                          | Description                |
|------------|-----------------------------------------|----------------------------|
| `text`     | `text`, `style` (`headline`/`title`/`caption`/`body`) | Text label     |
| `icon`     | `name`, `size`                          | Single icon                |
| `chip`     | `label`                                 | Material chip              |
| `button`   | `label`                                 | Flat button (non-functional in SDUI) |
| `card`     | `title`, `children`                     | Material card wrapper      |
| `metric`   | `icon`, `label`, `value`                | Classic icon-value-label   |
| `progress` | `value` (0.0–1.0), `label`             | Linear progress bar        |

---

## 4. Icon Reference

These icon name strings can be used in any `icon` property:

### Environment
`thermostat`, `co2`, `air`, `opacity`, `water_drop`, `water`, `wb_sunny`,
`wb_cloudy`, `rainy`, `ac_unit`, `local_fire_department`, `nights_stay`,
`wb_twilight`

### Energy
`bolt`, `solar_power`, `energy_savings_leaf`, `power`, `battery_full`,
`battery_charging_full`

### Metrics & Status
`speed`, `trending_up`, `trending_down`, `visibility`, `timer`, `update`,
`verified`, `info`, `check`, `warning`, `error`

### Building & Spaces
`home`, `meeting_room`, `elevator`, `stairs`, `chair`, `desk`,
`local_parking`, `accessible`

### People & Activities
`people`, `person`, `fitness_center`, `restaurant`, `schedule`, `event`,
`campaign`

### Lighting
`light`, `lightbulb`, `tungsten`, `wb_incandescent`, `light_mode`

### Services
`cleaning_services`, `security`, `construction`, `handyman`, `wifi`

### Health & Science
`health_and_safety`, `monitor_heart`, `science`, `biotech`, `eco`, `park`

### General
`star`, `favorite`, `thumb_up`, `notifications`

If an icon name is not found, `help_outline` (❓) is rendered.

---

## 5. Color Reference

Use these strings in any `color` property:

| Name     | Swatch            |
|----------|-------------------|
| `red`    | 🔴 Red            |
| `orange` | 🟠 Orange         |
| `amber`  | 🟡 Amber          |
| `green`  | 🟢 Green          |
| `blue`   | 🔵 Blue           |
| `indigo` | 💙 Indigo         |
| `purple` | 🟣 Purple         |
| `teal`   | 🩵 Teal           |
| `cyan`   | 🩵 Cyan (lighter) |
| `pink`   | 💗 Pink           |
| `brown`  | 🟤 Brown          |
| `grey`   | ⚪ Grey           |

When `color` is omitted or not recognised, the app's primary theme colour is
used.

---

## 6. Full Example Configs

### 6.1 Corporate HQ — Classic Comfort Metrics

A standard office dashboard: weather, 3 comfort metrics, temperature trend,
and an HVAC alert.

```json
{
  "type": "column",
  "crossAxisAlignment": "stretch",
  "children": [
    {
      "type": "weather_badge",
      "temp": "15", "unit": "°C", "label": "Outside", "icon": "wb_sunny"
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "grid",
      "columns": 3,
      "spacing": 10,
      "children": [
        { "type": "metric_tile", "icon": "thermostat", "value": "22.5", "unit": "°C", "label": "Temp" },
        { "type": "metric_tile", "icon": "co2",        "value": "820",  "unit": "ppm", "label": "CO2" },
        { "type": "metric_tile", "icon": "volume_up",  "value": "45",   "unit": "dB",  "label": "Noise" }
      ]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "trend_card",
      "title": "Temperature Trend",
      "subtitle": "Last 24 hours",
      "change": "+1.2°",
      "data": [15, 15, 18, 22, 25, 22.5],
      "labels": ["12AM", "6AM", "12PM", "6PM"]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "alert_banner",
      "icon": "thermostat",
      "title": "Building is Warming Up",
      "subtitle": "HVAC system is adjusting to reach target temperature.",
      "color": "orange"
    }
  ]
}
```

### 6.2 Research Lab — Energy & Sustainability

Features a hero banner, KPI cards for solar vs. grid, progress bars for
renewable share and battery, lab-specific environment tiles, CO₂ trend,
certification badges, and a sustainability alert.

```json
{
  "type": "column",
  "crossAxisAlignment": "stretch",
  "children": [
    { "type": "weather_badge", "temp": "9", "unit": "°C", "label": "Outside", "icon": "cloud" },
    { "type": "spacer", "height": 12 },
    {
      "type": "image_banner",
      "title": "Sustainability Dashboard",
      "subtitle": "Real-time energy & environment",
      "icon": "eco",
      "color": "green"
    },
    { "type": "spacer", "height": 16 },
    { "type": "section_header", "title": "Energy Usage", "icon": "bolt" },
    { "type": "spacer", "height": 8 },
    {
      "type": "grid", "columns": 2, "spacing": 10,
      "children": [
        { "type": "kpi_card", "title": "Solar Generation", "value": "42", "unit": " kW", "trend": "up", "color": "green" },
        { "type": "kpi_card", "title": "Grid Consumption", "value": "118", "unit": " kW", "trend": "down", "color": "orange" }
      ]
    },
    { "type": "spacer", "height": 12 },
    { "type": "progress_bar", "label": "Renewable share", "value": 26.2, "max": 100, "unit": "%", "color": "green" },
    { "type": "progress_bar", "label": "Battery storage", "value": 73, "max": 100, "unit": "%", "color": "blue" },
    { "type": "spacer", "height": 20 },
    { "type": "section_header", "title": "Lab Environment", "icon": "science" },
    { "type": "spacer", "height": 8 },
    {
      "type": "grid", "columns": 3, "spacing": 10,
      "children": [
        { "type": "metric_tile", "icon": "thermostat", "value": "21.0", "unit": "°C", "label": "Temp" },
        { "type": "metric_tile", "icon": "opacity",    "value": "55",   "unit": "%",    "label": "Humidity" },
        { "type": "metric_tile", "icon": "air",        "value": "12",   "unit": "µg/m³","label": "PM2.5" }
      ]
    },
    { "type": "spacer", "height": 12 },
    {
      "type": "trend_card",
      "title": "CO₂ Trend", "subtitle": "Last 12 hours", "change": "-45ppm",
      "data": [680, 720, 750, 710, 680, 650],
      "labels": ["6AM", "9AM", "12PM", "3PM"]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "badge_row",
      "badges": [
        { "label": "LEED Platinum", "icon": "verified", "color": "green" },
        { "label": "Net Zero Target", "icon": "eco", "color": "teal" },
        { "label": "ISO 50001", "icon": "energy_savings_leaf", "color": "blue" }
      ]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "alert_banner",
      "icon": "eco",
      "title": "Carbon-neutral today",
      "subtitle": "Solar + REC offsets exceed consumption for the day.",
      "color": "green"
    }
  ]
}
```

### 6.3 Co-Working Hub — Occupancy & Scheduling

Occupancy ring, comfort score, quick-stat rows, a day schedule timeline,
amenity badges, and a community event alert.

```json
{
  "type": "column",
  "crossAxisAlignment": "stretch",
  "children": [
    { "type": "weather_badge", "temp": "29", "unit": "°C", "label": "Outside", "icon": "wb_sunny" },
    { "type": "spacer", "height": 12 },
    {
      "type": "grid", "columns": 2, "spacing": 10,
      "children": [
        { "type": "occupancy_indicator", "label": "Space Occupancy", "percent": 73, "color": "orange" },
        { "type": "kpi_card", "title": "Comfort Score", "value": "8.4", "unit": "/10", "trend": "up", "color": "green" }
      ]
    },
    { "type": "spacer", "height": 16 },
    { "type": "section_header", "title": "Quick Stats", "icon": "speed" },
    { "type": "spacer", "height": 6 },
    { "type": "stat_row", "icon": "thermostat", "label": "Temperature", "value": "24.1 °C" },
    { "type": "stat_row", "icon": "opacity",    "label": "Humidity",    "value": "48%" },
    { "type": "stat_row", "icon": "volume_up",  "label": "Noise Level", "value": "52 dB", "color": "orange" },
    { "type": "stat_row", "icon": "light",      "label": "Lighting",    "value": "420 lux" },
    { "type": "stat_row", "icon": "wifi",       "label": "WiFi Signal", "value": "Strong", "color": "green" },
    { "type": "spacer", "height": 20 },
    { "type": "section_header", "title": "Today's Schedule", "icon": "schedule" },
    { "type": "spacer", "height": 8 },
    { "type": "schedule_item", "time": "09:00", "title": "Morning standup",     "subtitle": "Hot Desk Zone A", "icon": "people", "active": true },
    { "type": "schedule_item", "time": "11:30", "title": "Workshop: Flutter UI", "subtitle": "Meeting Room 2",  "icon": "event" },
    { "type": "schedule_item", "time": "14:00", "title": "Quiet Focus Time",    "subtitle": "Phone Booth 3",   "icon": "timer" },
    { "type": "spacer", "height": 16 },
    {
      "type": "badge_row",
      "badges": [
        { "label": "Free Coffee", "icon": "restaurant",     "color": "brown" },
        { "label": "Parking",     "icon": "local_parking",  "color": "blue" },
        { "label": "Gym",         "icon": "fitness_center", "color": "purple" }
      ]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "alert_banner",
      "icon": "campaign",
      "title": "Community Event at 5 PM",
      "subtitle": "Rooftop networking mixer — all members welcome.",
      "color": "blue"
    }
  ]
}
```

### 6.4 Wellness Centre — Health & Air Quality

Hero banner, wellbeing KPIs, four air-quality progress bars, comfort tiles,
AQI trend, building-detail info rows, certification badges, and a
quality alert.

```json
{
  "type": "column",
  "crossAxisAlignment": "stretch",
  "children": [
    { "type": "weather_badge", "temp": "5", "unit": "°C", "label": "Outside", "icon": "ac_unit" },
    { "type": "spacer", "height": 12 },
    {
      "type": "image_banner",
      "title": "Wellness Dashboard",
      "subtitle": "Your health-aware environment",
      "icon": "health_and_safety",
      "color": "teal"
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "grid", "columns": 2, "spacing": 10,
      "children": [
        { "type": "kpi_card", "title": "Wellbeing Index",   "value": "92", "unit": "%",    "trend": "up", "color": "teal" },
        { "type": "kpi_card", "title": "Air Quality Index", "value": "38", "unit": " AQI", "color": "green" }
      ]
    },
    { "type": "spacer", "height": 16 },
    { "type": "section_header", "title": "Air Quality Breakdown", "icon": "air" },
    { "type": "spacer", "height": 8 },
    { "type": "progress_bar", "label": "PM2.5", "value": 8,   "max": 50,   "unit": " µg/m³", "color": "green" },
    { "type": "progress_bar", "label": "PM10",  "value": 18,  "max": 100,  "unit": " µg/m³", "color": "green" },
    { "type": "progress_bar", "label": "TVOC",  "value": 220, "max": 500,  "unit": " ppb",   "color": "blue" },
    { "type": "progress_bar", "label": "CO₂",   "value": 480, "max": 1000, "unit": " ppm",   "color": "green" },
    { "type": "spacer", "height": 18 },
    { "type": "section_header", "title": "Comfort Metrics", "icon": "monitor_heart" },
    { "type": "spacer", "height": 8 },
    {
      "type": "grid", "columns": 3, "spacing": 10,
      "children": [
        { "type": "metric_tile", "icon": "thermostat", "value": "23.0", "unit": "°C",  "label": "Temp" },
        { "type": "metric_tile", "icon": "opacity",    "value": "50",   "unit": "%",   "label": "Humidity" },
        { "type": "metric_tile", "icon": "tungsten",   "value": "500",  "unit": "lux", "label": "Light" }
      ]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "trend_card",
      "title": "Indoor Air Quality", "subtitle": "AQI over 24 hours",
      "data": [42, 40, 38, 35, 38, 38],
      "labels": ["12AM", "6AM", "12PM", "6PM"]
    },
    { "type": "spacer", "height": 16 },
    { "type": "section_header", "title": "Building Details", "icon": "info" },
    { "type": "spacer", "height": 6 },
    { "type": "info_row", "icon": "cleaning_services", "label": "Last cleaned", "value": "08:30 AM today" },
    { "type": "info_row", "icon": "security",          "label": "Safety check", "value": "Passed ✓" },
    { "type": "info_row", "icon": "update",            "label": "HVAC filter",  "value": "Changed 3 days ago" },
    { "type": "spacer", "height": 16 },
    {
      "type": "badge_row",
      "badges": [
        { "label": "WELL Certified",     "icon": "health_and_safety", "color": "teal" },
        { "label": "Low VOC",            "icon": "air",               "color": "green" },
        { "label": "Circadian Lighting", "icon": "lightbulb",         "color": "amber" }
      ]
    },
    { "type": "spacer", "height": 16 },
    {
      "type": "alert_banner",
      "icon": "health_and_safety",
      "title": "Excellent Air Quality",
      "subtitle": "All pollutant levels well within safe limits.",
      "color": "green"
    }
  ]
}
```

---

## 7. Best Practices

1. **Always start with a root `column`** that has
   `"crossAxisAlignment": "stretch"` so widgets span the screen width.

2. **Use `spacer` nodes between groups** for consistent vertical rhythm
   (8–20 px). Don't rely on widget internal margins.

3. **Use `section_header` to separate logical groups** — it makes configs
   self-documenting and the dashboard easy to scan.

4. **Keep `grid` children homogeneous.** A grid of `metric_tile` nodes
   looks great; mixing types in one grid can produce uneven heights.

5. **Leverage `badge_row`** for certifications, amenities, or status labels
   rather than spelling them out in text.

6. **Use `kpi_card` for the 1–3 most important numbers** and
   `stat_row` for secondary data that doesn't need a full card.

7. **Place `alert_banner` near the bottom** so it doesn't compete with
   metrics for attention. Banners are coloured by severity:
   - `green` = positive / info
   - `blue` = neutral notice
   - `orange` = warning
   - `red` = critical alert

8. **Weather badge is auto-populated.** Set initial `temp`/`label` values
   in the config as fallbacks; the app injects live data from Open-Meteo.

9. **`trend_card` needs >= 2 data points.** Provide 4–8 evenly spaced
   points for a clean curve. `labels` should match the time span (e.g.
   hourly markers for a 24-hour chart).

10. **Test with the default dashboard fallback.** If your config returns
    `null`, the app renders `DefaultDashboard.config` — useful for
    buildings not yet configured.

---

## 8. Location Form Config

Separate from the dashboard config, the **location form** defines the
floor/room dropdowns for each building. It follows a simple schema:

```json
{
  "floors": [
    { "value": "1", "label": "Ground Floor" },
    { "value": "2", "label": "First Floor" }
  ],
  "rooms": {
    "1": [
      { "value": "reception", "label": "Reception" },
      { "value": "lobby",     "label": "Lobby" }
    ],
    "2": [
      { "value": "open-office", "label": "Open Office" },
      { "value": "conf-a",     "label": "Conference Room A" }
    ]
  }
}
```

- `floors` — ordered list of floor options.
- `rooms` — map from floor `value` to its list of room options.
- When `null` is returned, the app falls back to free-text entry fields.

---

## 9. Populating Dashboard Fields from 3rd-Party APIs

SDUI configs can contain **placeholder values** (`"--"`) for fields that
should be populated at runtime from external data sources. The app's
injection layer replaces these placeholders with live data fetched from
building-specific APIs.

### 9.1 Built-in Example: Real-Time Weather via Open-Meteo

The `weather_badge` widget is the canonical example of this pattern:

1. **Building location is stored in the database.** Each building record
   includes `latitude` and `longitude` fields.
2. **The SDUI config uses placeholder values:**

   ```json
   {
     "type": "weather_badge",
     "temp": "--",
     "unit": "°C",
     "label": "Outside",
     "icon": "cloud"
   }
   ```

3. **At runtime** the app resolves the active building's coordinates and
   calls the [Open-Meteo API](https://open-meteo.com/en/docs) (free, no
   API key required):

   ```
   GET https://api.open-meteo.com/v1/forecast
       ?latitude=37.77
       &longitude=-122.42
       &current=temperature_2m,relative_humidity_2m,apparent_temperature,
                wind_speed_10m,weather_code
       &timezone=auto
   ```

4. **The injection layer** (`DashboardScreen._injectWeather`) walks the
   SDUI tree, finds every `weather_badge` node, and overwrites `temp`,
   `icon`, and `label` with the live values.

5. **Caching & rate limiting:**
   - Results are cached in-memory for 15 minutes.
   - When the user presses the **Refresh** button the cache is cleared and
     a fresh API call is made.
   - A **per-user rate limit** (30 requests / hour by default) prevents
     abuse; once exceeded the cached (possibly stale) value is returned.

### 9.2 Extending the Pattern to Other Data Sources

The same approach works for **any** dashboard field that should reflect
live, building-specific data from a 3rd-party or internal API. Below are
examples showing how the config could be extended.

#### Example A — Indoor CO₂ from a Building IoT API

```json
{
  "type": "metric_tile",
  "icon": "co2",
  "value": "--",
  "unit": "ppm",
  "label": "CO₂",
  "_data_source": {
    "provider": "building_iot_api",
    "endpoint": "https://iot.example.com/v1/buildings/{buildingId}/sensors/co2",
    "field": "current_ppm",
    "refresh_seconds": 300
  }
}
```

The `_data_source` metadata tells the injection layer which API to call.
`{buildingId}` is interpolated from the active building. The response
JSON's `current_ppm` field replaces `"--"` in `value`.

#### Example B — Outdoor Air Quality from Open-Meteo Air Quality API

```json
{
  "type": "kpi_card",
  "title": "Air Quality Index",
  "value": "--",
  "unit": " AQI",
  "_data_source": {
    "provider": "open_meteo_air_quality",
    "url": "https://air-quality-api.open-meteo.com/v1/air-quality?latitude={lat}&longitude={lon}&current=european_aqi",
    "field": "current.european_aqi"
  }
}
```

`{lat}` and `{lon}` are resolved from the building's coordinates, just
like the weather badge. This is a **free API** with no key required.

#### Example C — Energy Consumption from a Utility API

```json
{
  "type": "kpi_card",
  "title": "Grid Consumption",
  "value": "--",
  "unit": " kW",
  "trend": "down",
  "color": "orange",
  "_data_source": {
    "provider": "utility_api",
    "endpoint": "https://energy.example.com/v1/meters/{meterId}/current",
    "field": "power_kw",
    "auth": "bearer",
    "refresh_seconds": 60
  }
}
```

#### Example D — Indoor Temperature from a BMS (Building Management System)

```json
{
  "type": "metric_tile",
  "icon": "thermostat",
  "value": "--",
  "unit": "°C",
  "label": "Indoor Temp",
  "_data_source": {
    "provider": "bms_api",
    "endpoint": "https://bms.example.com/api/zones/{zoneId}/temperature",
    "field": "value",
    "refresh_seconds": 120
  }
}
```

### 9.3 Implementation Approach

| Approach | How it works | Best for |
|----------|-------------|----------|
| **Server-side injection** | The backend resolves `_data_source` before returning the config. The app receives ready-to-render values. | Production deployments where the backend already aggregates sensor data. |
| **Client-side injection** | The app reads `_data_source`, makes the HTTP call, and patches the SDUI tree before rendering (as done today for `weather_badge`). | Lightweight deployments, free APIs, or when the backend has no integration layer. |
| **Hybrid** | The backend pre-fills most fields; the app refreshes a subset (e.g. weather) on demand. | Best of both worlds. |

### 9.4 Free APIs Suitable for Building Dashboards

| API | Data | URL | Key Required |
|-----|------|-----|-------------|
| **Open-Meteo Weather** | Temperature, humidity, wind, weather condition | `api.open-meteo.com/v1/forecast` | No |
| **Open-Meteo Air Quality** | AQI, PM2.5, PM10, ozone, NO₂ | `air-quality-api.open-meteo.com/v1/air-quality` | No |
| **Open-Meteo Geocoding** | City → lat/lon lookup | `geocoding-api.open-meteo.com/v1/search` | No |
| **Open UV** | UV index by location | `api.openuv.io/api/v1/uv` | Yes (free tier) |
| **PurpleAir** | Hyper-local air quality sensors | `api.purpleair.com/v1/sensors` | Yes (free tier) |

---

*This document covers SDUI config schema version 1 for ComfortOS.*
