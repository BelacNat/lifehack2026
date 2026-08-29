# Rescue My Fridge

This feature reads and writes the existing Supabase `fridge_items` table. It
does not create or alter any tables, columns, policies, or migrations.

## Included

- Expiry urgency calculated from each item's expiry date
- Rescue-only view for unconsumed food expiring soon
- Supabase-backed consumed actions
- Separate Expiring Soon and Rescue Recipes tabs
- AI rescue recipes generated automatically after fridge data loads
- Selectable recipe cards with a dedicated recipe-detail page
- Recipe ingredients include AI-generated two-pax quantities
- A pax selector scales recipe quantities from 1–8 people, capped by stock
- Recipe completion subtracts only the scaled quantities from matched items
- Pull-to-refresh and database error handling
- Automatic AI recipes using all safe, unconsumed food
- Rescue-soon ingredients prioritized ahead of fresher food
- Expandable recipe results with no manual recipe input required

## OpenAI recipe contract

The Flutter client calls the Supabase Edge Function
`openai-recipe-suggestions`. The deployed function keeps `OPENAI_API_KEY` in
server-side secrets and calls the OpenAI Responses API with Structured Outputs.
It uses `gpt-4o-mini`, requires a valid Supabase JWT, validates request data,
and excludes expired ingredients before recipe generation.

Client request:

```json
{
  "ingredients": [
    {
      "name": "Baby spinach",
      "quantity": 1,
      "unit": "bag",
      "days_until_expiry": 0
    }
  ],
  "recipe_count": 3
}
```

Expected function response:

```json
{
  "recipes": [
    {
      "title": "Recipe title",
      "summary": "Short description",
      "time_minutes": 20,
      "difficulty": "Easy",
      "servings": 2,
      "ingredients_used": [
        {
          "name": "Baby spinach",
          "quantity": 0.5,
          "unit": "bag"
        }
      ],
      "steps": ["First step", "Second step"],
      "waste_saving_tip": "Storage or reuse advice"
    }
  ]
}
```

Reference: [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
