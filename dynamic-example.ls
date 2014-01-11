
{ char, $or, any, except, then-keep, then-ignore, many, join-string, convert-rule-to-function } = require './src/parse'

# Based on example.ls, this example builds 2 parsers based on the same
# grammar at runtime.

# First, the function that builds a string parser, using code from example.ls:
build-parser = (quote-character) ->
	# This logic the same as example.ls, except that quote is built from
	# the quote-character argument, rather than a hard-coded '"' character.
	quote = char quote-character
	slash = char '\\'

	escapable = quote |> $or slash
	escaped-character = slash |> then-keep escapable
	unescaped-character = any! |> except escapable
	valid-character = escaped-character |> $or unescaped-character
	inner-content = valid-character |> many |> join-string

	# return the final rule
	quote
		|> then-keep inner-content
		|> then-ignore quote

# Now generate a parser for single quotes, double quotes, and backtick
# quotes just for fun.
double-quote-rule = build-parser '"'
single-quote-rule = build-parser "'"
wacky-quote-rule = build-parser "`"

# Now a rule to accept either
string-rule = double-quote-rule |> $or single-quote-rule |> $or wacky-quote-rule

# Convert the rule to a simpler function that we can just call
parse-function = convert-rule-to-function string-rule

# Now with the rule completed, try parsing some input:

# Should output the following:
# A "quoted" string with \ slashes
console.log parse-function '"A \\"quoted\\" string with \\\\ slahes"'

# A 'quoted' string with \ slashes
console.log parse-function "'A \\'quoted\\' string with \\\\ slahes'"

# A `quoted` string with \ slashes
console.log parse-function '`A \\`quoted\\` string with \\\\ slahes`'


