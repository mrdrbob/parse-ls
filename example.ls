# Example.ls
#
# In this example, we're building a simple parser to parse quoted 
# strings like you might see in many programing languages.
# The rules for our grammar will be:
# 1. Must start with a double-quote.
# 2. Quotes and slashes inside the string must be prefixed with a slash.
# 3. Must end with a double-quote.
#
# An example string:
# "This is a \"quoted\" string.  And a \\ slash."
#
# Which, after parsing, would be:
# This is a "quoted" string.  And a \ slash.
#
# You build a parser in parse.ls by creating very simple rules and then buliding up
# complexity by composing those rules together.  It's tempting to start in sequential
# order (first the quote, then the body rule, etc.), but generally you start from the
# inside-out, with the most simple rules (matching individual letters), buliding out 
# to the most complex rule (the final rule which will parse the entire string).
#
# A `rule` in Parse.ls terms is simply a method that takes some input (in a specific
# format), and either returns a successful value and the remaining input, or a failure
# result.

# To start, we import all the functions we're using from the parse.ls library.
{ char, $or, any, except, then-keep, then-ignore, many, join-string, convert-rule-to-function } = require './src/parse'
# This is the preferred method for importing functions, but you could also do:
# `parser = require './src/parse'` and then prefix any function with `parser.`
#
# Also note, that when using the library as installed by NPM, you would require
# `parse-ls` isntead.  IE: { char, ... } = require 'parse-ls'

# Next, we create simple rules to match the individual characters we're most
# interested in.  In this case, it's the `quote` and the `slash`, since these are the 
# "special" characters in our grammar.
quote = char '"'
slash = char '\\'

# Next we define which characters must be escaped in the content of the string.  By 
# piping to the `$or` function, we make a rule that will match either the `quote` rule
# OR the `slash` rule.
escapable = quote |> $or slash

# We define an escaped character: a slash followed by an escapable character. Here
# we pipe the slash character into the then-keep function.  The then-keep function 
# requires that the previous rule (`slash`) matches, and then attempst the rule
# passed to it (`escapable`).  If both succeed, it returns the result of the second
# rule (`escapable`).  There is a `then-ignore` function as well that keeps the 
# results of the first rule and ignores the results of the second.
escaped-character = slash |> then-keep escapable

# Next we define all the characters that do not require an escape code.  This would
# be everything that isn't an `escapable` character.  This is done by calling `any!`, 
# which creates a rule that matches anything, then piping to `except` which  will 
# fail if the rule passed to it matches (`escapable`).
unescaped-character = any! |> except escapable

# Now to combine the two types of characters that are valid inside the string, 
# `escaped-character` and `unescaped-character`.
valid-character = escaped-character |> $or unescaped-character

# Now that we have a rule that will match any character that is valid for the inner
# content, we need to repeat that rule until it fails.  That's exactly what `many`
# does.  It will repeat the rule until it fails and return the result as an array,
# even if the array is empty.  The join-string function conviently joins the results
# into a string.
inner-content = valid-character |> many |> join-string

# Now to finish the rule out with the opening and closing quotes.  This rule requires
# a `quote`, followed by the `inner-content` which is kept, then a trailing `quote` 
# which is ignored.
string-rule = quote
	|> then-keep inner-content
	|> then-ignore quote

# Finally, conver the rule into a function that can be called with just a string
# for input, and returns either a parsed result, or throws an exception with 
# details about the where the rule failed.
parse-function = convert-rule-to-function string-rule

# Now try parsing some input:
result = parse-function '"A \\"quoted\\" string with \\\\ slahes"'

# Should output the following:
# A "quoted" string with \ slashes
console.log result

# Should also still work w/ empty quotes
# Should output an empty string (**).
console.log '*' + (parse-function '""') + '*'

# For an example that uses the code above to create a parser that can handle
# single OR double quotes, see: dynamic-example.ls