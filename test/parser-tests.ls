
{ equal: eq, deep-equal: deep-eq } = require 'assert'
{ to-input, to-backwards-input, simple, with-error-message, any, char, map, debug, $then, then-keep, then-ignore, then-concat, then-null, then-array-concat, many, times, at-least, at-least-once, join-string, as-array, as-object-with-value, then-set, sequence, text, maybe, invert, delay, end, always, always-new, parse, convert-rule-to-function, line-and-column } = (require '../src/parse')

describe \Parser ->
	describe \to-input ->
		specify 'should convert a string into an input object' ->
			result = 'This is a test' |> to-input |> (.value!)
			deep-eq result, do
				string: 'This is a test',
				index: 0

	# One input to rule them most, er, most of them.
	input = to-input \string

	# Convenience methods
	should-fail = ->
		eq false, it.success

	should-fail-with-message = (message, res) -->
		eq false, res.success
		eq message, res.message

	should-match = (value, index, res) -->
		deep-eq { success: true, value } { res.success, res.value }
		deep-eq { string: \string, index: index },  res.remaining.value!

	should-throw = (message, rule, input) -->
		callback = -> input |> rule
		try
			callback!
		catch error
			eq message, error.message
			return
		throw new Error('Expected exception')

	describe \to-backwards-input ->
		specify 'creates an input object with expected functions' ->
			result = ('test' |> to-backwards-input)
			eq \function, typeof result.at-eof
			eq \function, typeof result.current
			eq \function, typeof result.next
			eq \function, typeof result.pos
		specify 'reports at eof immediately on empty strings' ->
			inp = ('' |> to-backwards-input)
			eq true, inp.at-eof!
		specify 'return results backwards' ->
			inp = ('123' |> to-backwards-input)
			eq false, inp.at-eof!
			eq '3', inp.current!
			two = inp.next!
			eq false, two.at-eof!
			eq '2', two.current!
			one = two.next!
			eq false, one.at-eof!
			eq '1', one.current!
			done = one.next!
			eq true, done.at-eof!

	describe \simple ->
		specify 'returns a success result and moves the input when the rule succeeds' ->
			match-function = (c) -> c == \s
			input |> simple match-function |> should-match \s, 1
		specify 'returns a failure when match-function returns false' ->
			match-function = (c) -> c == \0
			input |> simple match-function |> should-fail
		specify 'works with more complex rules' ->
			match-function = -> it >= 'a' && it <= 'z'
			input |> simple match-function |> should-match \s, 1

	describe \with-error-message ->
		specify 'should override the error message of a failure' ->
			match-function = (c) -> c == \a
			result = input |> (simple match-function |> with-error-message 'expected "a"')
			eq false, result.success
			eq 'expected "a"', result.message
		specify 'should only override the the current error message' ->
			match-s = (simple (c) -> c == \s) |> with-error-message 'expected "s"'
			match-a = (simple (c) -> c == \a) |> with-error-message 'expected "a"'
			result = input |> (match-s |> then-concat match-a)
			eq false, result.success
			eq 'expected "a"', result.message
			eq 1, result.last-success.value!.index
		specify 'should not affect successes' ->
			match-function = (c) -> c == \s
			result = input |> (simple match-function |> with-error-message 'expected "s"') |> should-match \s, 1


	describe \any ->
		specify 'always succeeds if there is input to be consumed and consumes input' ->
			input |> any! |> should-match \s, 1
		specify 'fails when at eof' ->
			'' |> to-input |> any! |> should-fail
		specify 'matches rule in list and returns its result' ->
			a = char \a
			s = char \s
			d = char \d
			f = char \f
			input |> any a,s,d,f |> should-match \s, 1
		specify 'fails when at eof and rules are specified' ->
			a = char \a
			s = char \s
			d = char \d
			f = char \f
			'' |> to-input |> any a,s,d,f |> should-fail
		specify 'exits early when a matching rule is found' ->
			a = char \a
			s = char \s
			d = char \d
			f = char \f |> map -> throw 'Should never happen'
			input |> any a,s,d,f |> should-match \s, 1
		specify 'fails when nothing matches' ->
			a = char \a
			d = char \d
			f = char \f |> map -> throw 'Should never happen'
			input |> any a, d, f |> should-fail

	describe \char ->
		specify 'successfully matches a single character' ->
			input |> char \s |> should-match \s, 1
		specify 'fails when single character does not match' ->
			input |> char \a |> should-fail
		specify 'fails when no further input' ->
			'' |> to-input |> char 'a' |> should-fail

	describe \map ->
		specify 'converts a value to something else' ->
			rule = char \s |> map -> [it]
			input |> rule |> should-match [\s], 1
		specify 'passes through failures' ->
			rule = char \t |> map -> [it]
			input |> rule |> should-fail

	describe \debug ->
		specify 'executes function after rule without changing result' ->
			debug-has-run = false
			rule = char \s |> debug -> debug-has-run := true
			input |> rule |> should-match \s, 1
			eq true, debug-has-run
		specify 'does not execute if rule failed' ->
			debug-has-run = false
			rule = char \t |> debug -> debug-has-run := true
			input |> rule |> should-fail
			eq false, debug-has-run

	describe \$then ->
		specify 'executes one rule then the next and calls the combine function' ->
			rule = char \s |> $then (char \t), (one, two) -> { one, two }
			input |> rule |> should-match { one: \s, two: \t }, 2
		specify 'fails when the first rule fails' ->
			rule = char \a |> $then (char \t), (one, two) -> { one, two }
			input |> rule |> should-fail
		specify 'fails when the second rule fails' ->
			rule = char \s |> $then (char \a), (one, two) -> { one, two }
			input |> rule |> should-fail
		specify 'can keep results of second rule' ->
			rule = char \s |> then-keep (char \t)
			input |> rule |> should-match \t, 2
		specify 'can ignore results of second rule' ->
			rule = char \s |> then-ignore (char \t)
			input |> rule |> should-match \s, 2
		specify 'can concat results' ->
			rule = char \s |> then-concat (char \t)
			input |> rule |> should-match \st, 2
		specify 'can ignore all results' ->
			rule = char \s |> then-null (char \t)
			input |> rule |> should-match null, 2
		specify 'can concat array results' ->
			rule = char \s |> (map -> [it]) |> then-array-concat (char \t |> (map -> [it]))
			input |> rule |> should-match [\s, \t], 2

	describe \many ->
		specify 'executes a rule many times and returns results as an array' ->
			rule = any! |> many
			input |> rule |> should-match [\s,\t,\r,\i,\n,\g], 6
		specify 'unsuccessful rules still return an emtpy array' ->
			rule = char \a |> many
			input |> rule |> should-match [], 0
		specify 'partial matches succeed and stop at correct point' ->
			rule = char \s |> many
			input |> rule |> should-match [\s], 1
		specify 'matches can be joined to a string' ->
			rule = any! |> many |> join-string
			input |> rule |> should-match \string, 6

	describe \times ->
		specify 'expects a rule to succeed at least x times and stops' ->
			rule = any! |> times 3
			input |> rule |> should-match [\s, \t, \r], 3
		specify 'fails when a rule does not match enough times' ->
			rule = char \s |> times 2
			input |> rule |> should-fail-with-message "expected 's' 1 more time(s)"
		specify 'always succeeds when a rule is required to match 0 times' ->
			rule = char \a |> times 0
			input |> rule |> should-match [], 0
		specify 'fails when a rule never matches but should at least once' ->
			rule = char \a |> times 1
			input |> rule |> should-fail

	describe \at-least-once ->
		specify 'executes many times and returns results as an array' ->
			rule = any! |> at-least-once
			input |> rule |> should-match [\s,\t,\r,\i,\n,\g], 6
		specify 'returns a failure if not matches' ->
			rule = char \a |> at-least-once
			input |> rule |> should-fail
		specify 'succeeds on a single success' ->
			rule = char \s |> at-least-once
			input |> rule |> should-match [\s], 1

	describe \at-least ->
		specify 'executes at least x times and continues' ->
			rule = any! |> at-least 3
			input |> rule |> should-match [\s, \t, \r, \i, \n, \g], 6
		specify 'fails when not enough matches' ->
			rule = char \s |> at-least 2
			input |> rule |> should-fail-with-message "expected 's' 1 more time(s)"
		specify 'always succeeds when a rule is required to match 0 times' ->
			rule = char \a |> at-least 0
			input |> rule |> should-match [], 0

	describe \as-array ->
		specify 'returns any result as an array of 1, containing the result' ->
			rule = (text \str) |> as-array
			input |> rule |> should-match [ \str ], 3

	describe \as-object-with-value ->
		specify 'returns an object with the current result as a property of that object' ->
			rule = (text \str) |> as-object-with-value 'firstChars'
			input |> rule |> should-match { firstChars: \str }, 3

	describe \then-set ->
		specify 'sets a property of the current result to the result of the next rule' ->
			rule = (text \str)
				|> as-object-with-value 'firstChars'
				|> then-set 'lastChars', (text \ing)
			input |> rule |> should-match { firstChars: \str, lastChars: \ing }, 6

	describe \sequence ->
		specify 'executes rules in sequence, passes if all pass' ->
			rules =
				char \s
				char \t
				char \r
				...
			input |> sequence rules |> should-match [\s, \t, \r], 3
		specify 'fails when any rule fails' ->
			rules =
				char \s
				char \r
				char \t
				...
			input |> sequence rules |> should-fail

	describe \text ->
		specify 'should match exact cases' ->
			input |> (text \string) |> should-match \string, 6
		specify 'should fail on case mismatch' ->
			input |> (text \strinG) |> should-fail
		specify 'should fail on partial match' ->
			input |> (text \stringlong) |> should-fail

	describe \maybe ->
		specify 'should allow failed matches' ->
			input |> (text \whoops |> maybe) |> should-match null, 0
		specify 'should allow successful matches' ->
			input |> (text \str |> maybe) |> should-match \str, 3

	describe \invert ->
		specify 'should allow failed matches' ->
			input |> (char \a |> invert) |> should-match \s, 1
			specify 'should fail matches' ->
				input |> (char \s |> invert) |> should-fail

	describe \end ->
		specify 'should fail when input is remaining' ->
			input |> (text \str |> end) |> should-fail
		specify 'should succeed when input is consumed' ->
			input |> (text \string |> end) |> should-match \string, 6

	describe \always ->
		specify 'always returns a value without consuming input' ->
			input |> always \1 |> should-match \1, 0

	describe \always-new ->
		specify 'returns result of callback without consuming input' ->
			count = 0
			callback = -> count := count + 1
			input |> always-new callback |> should-match 1, 0
			input |> always-new callback |> should-match 2, 0

	describe \delay ->
		specify 'returns a rule at parse time' ->
			called = 0
			delayed = delay (input) ->
				called := called + 1
				if called == 1 then (char \s) else (char \t)
			rule = delayed |> then-concat delayed
			input |> rule |> should-match \st, 2
			eq called, 2

	describe \parse ->
		specify 'returns value if rule was successful' ->
			result = input |> (text \string |> end |> parse)
			eq result, \string
		specify 'throws an exception if rule fails' ->
			input |> (text \st |> end |> parse |> should-throw 'expected end-of-input at line 1, column 3')

	describe \convert-rule-to-function ->
		rule = char \s |> then-concat (char \t)
		rule-function = convert-rule-to-function rule

		specify 'reusable function returns simplified results' ->
			correct-result = rule-function \st
			eq \st, correct-result

		specify 'failed parse call throws an exception' ->
			try
				rule-function \bad
			catch error
				eq "expected 's' at line 1, column 1", error.message
				return
			throw new Error('expected exception')

	describe \line-and-column ->
		specify 'correctly counts \\n lines and columns' ->
			# col              1234 123  123
			# line             1    2    3
			# index            0123 4567 89
			input = { string: 'abc\nefg\nhij', index: 9 }
			result = line-and-column input
			deep-eq result, do
				line: 3,
				column: 2
		specify 'handles \\r line endings' ->
			# col              1234 123  123
			# line             1    2    3
			# index            0123 4567 89
			input = { string: 'abc\refg\rhij', index: 9 }
			result = line-and-column input
			deep-eq result, do
				line: 3,
				column: 2
		specify 'handles CRLF line endings' ->
			# col              1234 123  123
			# line             1    2    3
			# index            0123 4 5678 8 901
			input = { string: 'abc\r\nefg\r\nhij', index: 11 }
			result = line-and-column input
			deep-eq result, do
				line: 3,
				column: 2

	describe \documentation ->
		specify 'quoted string example works' ->
			quote = char '"'
			slash = char '\\'
			escapable = any quote, slash
			escaped-character = slash |> then-keep escapable
			unescaped-character = invert escapable
			valid-character = any escaped-character, unescaped-character
			inner-content = valid-character |> many |> join-string
			string-rule = quote
				|> then-keep inner-content
				|> then-ignore quote
			
			parse-function = convert-rule-to-function string-rule
			result = parse-function '"A \\"quoted\\" string with \\\\ slahes"'

			eq 'A "quoted" string with \\ slahes', result
