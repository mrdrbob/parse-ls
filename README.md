Parse.ls
========

Parse.ls is a library for writing parsers in [LiveScript](http://livescript.net/).  It takes advantage of LiveScript's unique syntax to allow you to define your parser in code in a clear, declarative manner.  Parsers are built up from simple rules which are composed like building blocks to create the much more complex final product.

Parse.ls has no dependencies, but works best with LiveScript's syntax.  Parse.ls requires the entire string be loaded into memory, so it's probably not the best choice for parsing large streams of data.

A Short Example
---------------

Here's a parser that would parse something like a Javascript string literal (with double quotes).  For a heavily commented version of this code, see [example.ls](example.ls).  For an example that will do both single and double quotes, see [dynamic-example.ls](dynamic-example.ls).

```ls
{ char, $or, any, except, then-keep, then-ignore, many, join-string, convert-rule-to-function } = require 'parse-ls'

quote = char '"'
slash = char '\\'

escapable = quote |> $or slash
escaped-character = slash |> then-keep escapable
unescaped-character = any! |> except escapable
valid-character = escaped-character |> $or unescaped-character
inner-content = valid-character |> many |> join-string
string-rule = quote
	|> then-keep inner-content
	|> then-ignore quote

parse-string-literal = convert-rule-to-function string-rule
parse-string-literal '"I love \\"unnecessary\\" quotes!"' # I love "unnecessary" quotes!
```

What is a Rule?
---------------

In parse.ls, a rule is a simple function that accepts an input and returns a result, with either a success status or a failure status.

Rules expect input in the following format:

```json
{
	"string": "An example input",
	"index": 5
}
```

The input contains a reference to the full `string` being evaluated, and an `index` of where the parser is currently at.  Input in this format should be treated as immutable.  When a rule consumes input, it does not change the current input, but returns a new input with only the `index` changed.  IE:

```json
{
	"string": "An example input",
	"index": 6
}
```

Rules should return output in one of the following formats.  For a failure, the rule returns failure status, the successfully parsed input so far (in the same format as above), and any last known parsed value if applicable:

```json
{
	"success": false,
	"message": "expected 'z'"
	"lastSuccess": {
		"string": "An example input",
		"index": 6
	},
	"lastValue": "a"
}
```

For a success:

```json
{
	"success": true,
	"value": "[the parsed value]",
	"remaining": {
		"string": "An example input",
		"index": 7
	}
}
```

The success result has a true `success` status, contains the parsed `value` (which could be any thing: a string, an array, an object, etc.), and the `remaining` input after the rule has consumed input.

For example, he's a simple rule that will match any numeric digit passed to it, written in LiveScript:

```ls
matches-digit = (input) ->
	# if we're at the end of the input, return failure.
	return { success: false, message: 'unexpected end of file', last-success: input } if (input.index >= input.string.length)

	# get the current char
	current-character = input.string.charAt input.index

	# see if it's in range
	is-in-range = current-character >= \0 && current-character <= \9

	# Return a failure result if it's not in range.
	if !is-in-range
		{ success: false, message: 'expected a digit', last-success: input }
	else
		# Otherwise, return a success with the matched character as a
		# value.  Also return a new input with the index incremented by
		# 1, which is how many characters of input this rule consumed.
		{
			success: true,
			value: current-character,
			remaining: {
				string: input.string,
				index: input.index + 1
			}
		}
```

There's a lot of plumbing in this rule that's already taken care of in the parse.ls framework, and this could much more succinctly be written as:

```ls
matches-digit = (simple -> it >= \0 and it <= \9) |> with-error-message 'expected a digit'
```

Take a look at the [parse.ls](src/parse.ls) source file and the [unit tests](test/parser-tests.ls) for more examples.

Available Rules
---------------

These are the rules that are included with Parse.ls.  To see basic examples of these rules in use, check out the [unit tests](test/parser-tests.ls) or [example.ls](example.ls).

`to-input (string)`: Rules require the input be a specific format.  This is a convenience method to convert strings to that format.

`simple (delegate)` - The most basic rule.  It accepts a delegate that accepts one parameter (the individual character being tested), and returns true if the letter is matched, otherwise false.
 
`with-error-message(message)` - A rule to change the error message from the last rule (if it fails).  This is useful for rules like `simple` that just return generic error messages.  For example, an error message from `match-a = simple (c) -> c == \a` would simply say `simple rule failed`.  To make the error message more clear, you could do this: `match-a = (simple (c) -> c == \a) |> with-error-message 'expected "a"``.

`any ()` - Will match any character at all and consume that input.  If the input is at the end, it will fail.

`char (character)` - Matches an individual, specific character.

`map (delegate)` - Accepts a delegate to convert the current result to a different form.

`debug (delegate)` - Injects code into the parsing pipeline without effecting the output.   Useful for putting in debugging `console.log` statements.

`$then (rule, delegate)` - Accepts a rule and delegate.  If the prior rule in the chain succeeds, and the rule passed into this function succeeds, the results of both rules are passed as the two arguments to the delegate.  The result of the delegate becomes the parsed value.

`then-keep (rule)` - `$then` shorthand that keeps the result of the second rule and throws away the first.

`then-ignore (rule)` - `$then` shorthand that keeps the result of the first rule and throws away the second.

`then-concat (rule)` - `$then` shorthand to add/concatenate the results of the previous and next rule in the chain.

`then-null (rule)` - `$then` shorthand to execute the next rule in the chain, but throw away all current results and return null as the value.

`then-array-concat (rule)` - `$then` shorthand to concatenate the results of the next rule under the assumption that both rules return arrays.
 
`$or (rule)` - Attempts the `first` rule, if it succeeds, return its results, otherwise attempts the `second` rule.

`any-of (array-of-rules)` - Accepts an array of rules and returns the first result that succeeds.

`many ()` - Attempts a rule repeatedly until it fails, returning results in an array.  Rules that fail immediately still succeed with empty arrays.

`times (integer)` - Attempts a rule a set number of times.  A rule can match more than the specified times, but will only be applied the specified number of times.  If the input does not match enough times, the rule fails.  May be useful for parsing fixed-width fields, like dates in a YYYY-MM-DD format.  A rule requiring 0 matches will always succeed.

`join-string ()` - Convenience method for joining an array result into a string.  The equivalent of `map -> it.join ''`.

`at-least-once ()` - Like `many`, but requires the rule match at least once.

`sequence (array-of-rules)` - Accepts an array of rules and requires that all rules succeed.  Returns the results of each rule in an array.

`text (string)` - Matches a string exactly and returns it as the result.

`maybe ()` - Makes the preceding rule optional.  If the rule doesn't match, a success result with a null value is returned.
 
`except (rule)` - Accepts a rule as an argument, and matches anything that doesn't match that rule.
 
`do-until (rule)` - Accepts a rule as an argument, and matches anything until that rule matches, and returns the results in an array.

`expect-end ()` - A rule that expects the input to be at the end.  It succeeds if the input is at the end, otherwise fails.

`end ()` -  Convenience method to tack on to a rule chain to ensure input is completely consumed.

`delay` - Allows you to dynamically return a rule during the parse process, rather than during parser construction.  Useful for circular-referencing rules.  See below:

```ls
command  = null
command-delay = delay -> command
command-block = char '{'
	|> then-keep (command-delay |> many)
	|> then-ignore (char '}')
command = get-command |> $or set-command |> $or command-block
```

`always ()` - Always returns a result without consuming input.  Useful for optional values or starting off with a particular object as the value.

`parse ()` - Attempts to parse the input, returns the value if successful, otherwise false

`convert-rule-to-function (rule)` - Converts a rule to a function which either returns a value, or false if the value could not be parsed.

Utility Functions
-----------------

Included are a few utility functions that aren't exactly rules, but may make writing custom rules more clear.

`input-at-eof (input)` - Accepts an input object and returns true if the index is at or beyond the length of the input.

`input-next (input)` - Accepts an input object and returns a new input object with the index incremented by one.

`input-current-letter (input)` - Accepts an input object and returns the char at the current index.

`pass (value, remaining)` - Accepts a parsed value and the remaining input (after a rule has run) and returns a result object.

`fail (message, last-successful-input, parsed-value)` - Accepts an error message, an input object, and optionally a parsed value.  The error message describes what failed, the input object represents the last successfully parsed input, and the parsed value (if provided) is the last successfully parsed value.

Also one function to make error reporting more clear:

`line-and-column ({string, index})` - Accepts a string and an index (an input object), and calculates the line and column number of the index.  Useful for returning an error position in a format that is more friendly for text editors.

Todo
----

- More documentation with more complete examples that make use of all included rules.
