{ inherits } = require \util

!function ParseError message, last-success, position
	Error.call this
	Error.captureStackTrace this, arguments.callee
	this.message = message
	@name = @@name
	@last-success = last-success
	@position = position


inherits ParseError, Error

# Creates an interface to a string (or token array) that conforms to the expectations of the rules
to-input = (str, index = 0) ->
	current: -> str[index]
	at-eof: -> index >= str.length
	next: -> to-input str, index + 1
	pos: -> line-and-column { string: str, index }
	value: -> { string: str, index }

to-backwards-input = (str, index = str.length - 1) ->
	current: -> str[index]
	at-eof: -> index < 0
	next: -> to-backwards-input str, index - 1
	pos: -> line-and-column { string: str, index: (str.length - index) }
	value: -> { string: str, index }

# Utility function to create successful result object
pass = (value, remaining) -> { success: true, value, remaining }

# Utility function to return a failure result object
fail = (message, last-success, last-value) -> { success: false, message, last-success, last-value }

# Maps a failure message.  Useful for rules like 'simple' that return generic error messages.
with-error-message = (message, rule, input) --> if (res = rule input).success then res else fail message, res.last-success, res.last-value

# A basic rule.  `test` should be a function that expects 1 character and returns true if that character matches the critera.
simple = (test, input) --> if !(input.at-eof!) && test (value = input.current!) then pass value, (input.next!) else fail 'simple rule failed', input

# If no parameters are passed, then rule matches any input, otherwise will succeed with value of first matching rule, otherwise fails
any = (...rules) ->
	console.log rules?
	if !rules.length
		simple -> true
	else
		(input) ->
			for rule in rules
				if (res = rule input).success
					return res
			fail 'No rule matched', null, null

# Matches a single character.
char = (c) -> (simple -> it == c) |> with-error-message "expected '#{c}'"

# Converts a value from a previous rule to something different
map = (convert, rule, input) --> if !(res = rule input).success then res else pass (convert res.value), res.remaining

# Injects a function between rules for debugging
debug = (do-this, rule) --> rule |> map ->
	do-this!
	it

# Matches the `first` rule, if it succeeds, then the `second` rule.  If both succeed, executes the `combine` method to combine their results into a single value.
$then = (second, combine, first, input) --> if (res1 = first input).success then (if (res2 = second res1.remaining).success then pass (combine res1.value, res2.value), res2.remaining else res2) else res1

# Shorthand to keep the results of the next rule in the chain
then-keep = (rule) -> $then rule, (x, y) -> y

# Shorthand to ignore the results of the next rule in the chain
then-ignore = (rule) -> $then rule, -> it

# Shorthand to add/concat the results of the previous and next rule in the chain
then-concat = (rule) -> $then rule, (+)

# Shorthand to execute the next rule in the chain, but throw away all current results
then-null = (rule) -> $then rule, -> null

# Shorthand to concat the results of the next rule under the assumption that both rules are arrays
then-array-concat = (rule) -> $then rule, (++)

# Attempts a rule repeatedly until it fails, returning results in an array.  Rules that fail immediately still succeed with empty arrays
many = (rule, input) -->
	output = []
	remaining = input
	while (res = rule remaining).success
		output.push res.value
		remaining = res.remaining
	pass output, remaining

# Expects a rule to succeed exactly `count` times.
times = (count, rule, input) -->
	output = []
	remaining = input
	while (res = rule remaining).success and count
		output.push res.value
		remaining = res.remaining
		count -= 1
	if count
		fail "#{res.message} #{count} more time(s)"
	else
		pass output, remaining

# Expects a rule to succeed at least `count` times.
at-least = (count, rule) --> rule |> times count |> then-array-concat (rule |> many)

# Like `many`, but requires the rule match at least once
at-least-once = (rule) -> rule |> at-least 1

# Convenience method for joining an array result into a string
join-string = (rule) -> rule |> map -> it.join ''

# Convenience method for changing a single result into an array of 1 result.  Useful when
# the following rules return arrays and you wish to concatenate them.  For example, an
# identifier might allow only letters for the first character, followed by letters or numbers, might
# look like: (letter |> as-array) |> then-array-concat (letter-or-number |> many)
# Equivalent to `map -> [it]`
as-array = (rule) -> rule |> map -> [ it ]

# Converts a result into an object with a property of `name` that is the result.
# For example, `headers |> as-object-with-value 'requestHeader'` might return `{ requestHeader: 'Some value' }`
as-object-with-value = (name, rule) --> rule |> map -> (obj = {})[name] = it; obj

# Sets a property on the current result to value returned by rule.  Useful if your current result
# is an object, this is a shorthand way of setting a value on that result.  For example:
# headers |> as-object-with-value 'requestHeader' |> then-set 'requestDomain', domain` might return
# `{ requestHeader: 'Some value', requestDomain: 'other value' }`
then-set = (name, rule) --> $then rule, (x, y) -> x[name] = y; x

# Requires `rules` succeed in sequence.  If any part fails, the entire sequence fails.
sequence = (rules, input) -->
	remaining = input
	output = []
	for r in rules
		if !(res = r remaining).success
			return res
		output.push res.value
		remaining = res.remaining
	pass output, res.remaining

# Matches a string exactly
text = (value) ->
	rules = []
	for c in value
		rules.push (char c)
	sequence rules |> join-string

# Makes the preceeding rule optional.  If the rule doesn't match, a success result with a null value is returned.
maybe = (rule, input) --> if (res = rule input).success then res else pass null, input

# Negates a rule.  Returns anything that doesn't match the rule.
invert = (rule, input) --> if (res = rule input).success then fail 'unexpected input' else pass input.current!, input.next!

# Rule to exept the input to be at the end
expect-end = (input) -> if input.at-eof! then pass null, input else fail 'expected end-of-input', input

# Convience method to tack on to a rule chain to ensure input is completely consumed.
end = (rule) -> rule |> then-ignore expect-end

# Allows you to use a rule during the parse, rather than during parser construction.  Useful for circular-referencing rules.
# command  = null
# command-delay = delay -> command
# command-block = char '{'
# 	|> then-keep (command-delay |> many)
#		|> then-ignore (char '}')
# command = any get-command, set-command, command-block
#
delay = (getRule, input) --> getRule! input

# Always returns a result without consuming input.  Useful for optional values or starting off with a particular object as the value.
always = (value, input) --> pass value, input

# Always returns a success with the result of the callback as the value. Does not consume input.
always-new = (callback, input) --> pass callback!, input

# Attempts to parse the input, returns the value if successful, otherwise throws an exception
parse = (rule, input) -->
	if (res = rule input).success
		res.value
	else
		message = res.message
		if res.last-success
			pos = res.last-success.pos!
			message = "#{message} at line #{pos.line}, column #{pos.column}"
		throw new ParseError message, res.last-success, pos

# Converts a rule to a function which either returns a value, or throws an exception if the value could not be parsed.
convert-rule-to-function = (rule, input-string) --> to-input input-string |> (rule |> parse)

# Converts an index into a line and column position to make errors easier to find in text editors
line-and-column = ({string, index}) ->
	last-char = null
	line = 1
	column = 0

	for x from 0 to index
		c = string.char-at x
		column += 1
		if c == '\n' or c == '\r'
			# reset the column
			column = 0
			# Last-char prevents windows line-endings (\r\n) from counting as 2 lines.
			if c == '\r' or last-char != '\r'
				line += 1
		last-char = c

	{ line, column }

module.exports = { to-input, to-backwards-input, pass, fail, simple, with-error-message, any, char, map, debug, $then, then-keep, then-ignore, then-concat, then-null, then-array-concat, many, times, at-least, at-least-once, join-string, as-array, as-object-with-value, then-set, sequence, text, maybe, invert, delay, end, always, always-new, parse, convert-rule-to-function, line-and-column }
