
# Converts a string to a standard input object which rules will know how to process.
to-input = (str) -> 
	string: str
	index: 0

# Utility function to take an input and return the input at the next point.
input-next = ({string, index}) -> {string, index: index + 1}

# Utility function that validates that the input is not at or beyond the end of input.
input-at-eof = ({string, index}) -> index >= string.length

# Utility function that returns the character at the current index.
input-current-letter = ({string, index}) -> string.charAt(index)

# Utility function to create successful result object
pass = (value, remaining) -> { success: true, value, remaining }

# Utility function to return a failure result object
fail = (message, last-success, last-value) -> { success: false, message, last-success, last-value }

# Maps a failure message.  Useful for rules like 'simple' that return generic error messages.
with-error-message = (message, rule, input) --> if (res = rule input).success then res else fail message, res.last-success, res.last-value

# A basic rule.  `test` should be a function that expects 1 character and returns true if that character matches the critera.
simple = (test, input) --> if !(input-at-eof input) && test (value = input-current-letter input) then pass value, (input-next input) else fail 'simple rule failed', input

# A simple rule that always succeeds and consumes input.
any = -> simple -> true

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

# Attempts the `first` rule, if it succeeds, return its results, otherwise attempts the `second` rule.
$or = (second, first, input) --> if (res1 = first input).success then res1 else (if (res2 = second input).success then res2 else fail "#{res1.message} or #{res2.message}", input)

# Returns the first result that matches any of the provied `rules`
any-of = (rules, input) -->
	for r in rules
		if (res = r input).success
			return res
	fail 'any-of failed', input

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

# Expects a rule to succeed exactly `count` times.
at-least = (count, rule) --> rule |> times count |> then-array-concat (rule |> many)

# Like `many`, but requires the rule match at least once
at-least-once = (rule) -> rule |> at-least 1

# Convenience method for joining an array result into a string
join-string = (rule) -> rule |> map -> it.join ''

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

# Matches anything that doesn't match the `bad` rule.
except = (bad, rule, input) --> if (bad input).success then fail 'except matched', input else (rule input)

# Matches until `bad` rule succeeds
do-until = (bad, rule) --> rule |> except bad |> many

# Rule to exept the input to be at the end
expect-end = (input) -> if input-at-eof input then pass null, input else fail 'expected end-of-input', input

# Convience method to tack on to a rule chain to ensure input is completely consumed.
end = (rule) -> rule |> then-ignore expect-end

# Allows you to use a rule during the parse, rather than during parser construction.  Useful for circular-referencing rules.
# command  = null
# command-delay = delay -> command
# command-block = char '{'
# 	|> then-keep (command-delay |> many)
#		|> then-ignore (char '}')
# command = get-command |> $or (set-command) |> $or command-block
#
delay = (getRule, input) --> getRule! input

# Always returns a result without consuming input.  Useful for optional values or starting off with a particular object as the value.
always = (value, input) --> pass value, input

# Attempts to parse the input, returns the value if successful, otherwise false
parse = (rule, input) --> if (res = rule input).success then res.value else false;

# Converts a rule to a function which either returns a value, or false if the value could not be parsed.
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

module.exports = { to-input, input-next, input-at-eof, input-current-letter, pass, fail, simple, with-error-message, any, char, map, debug, $then, then-keep, then-ignore, then-concat, then-null, then-array-concat, $or, any-of, many, times, at-least, at-least-once, join-string, sequence, text, maybe, except, do-until, delay, end, always, parse, convert-rule-to-function, line-and-column }
