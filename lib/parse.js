(function(){
  var inherits, toInput, toBackwardsInput, pass, fail, withErrorMessage, simple, any, char, map, debug, $then, thenKeep, thenIgnore, thenConcat, thenNull, thenArrayConcat, many, times, atLeast, atLeastOnce, joinString, asArray, asObjectWithValue, thenSet, sequence, text, maybe, invert, expectEnd, end, delay, always, alwaysNew, parse, convertRuleToFunction, lineAndColumn, slice$ = [].slice;
  inherits = require('util').inherits;
  function ParseError(message, lastSuccess, position){
    Error.call(this);
    Error.captureStackTrace(this, arguments.callee);
    this.message = message;
    this.name = constructor.name;
    this.lastSuccess = lastSuccess;
    this.position = position;
  }
  inherits(ParseError, Error);
  toInput = function(str, index){
    index == null && (index = 0);
    return {
      current: function(){
        return str[index];
      },
      atEof: function(){
        return index >= str.length;
      },
      next: function(){
        return toInput(str, index + 1);
      },
      pos: function(){
        return lineAndColumn({
          string: str,
          index: index
        });
      },
      value: function(){
        return {
          string: str,
          index: index
        };
      }
    };
  };
  toBackwardsInput = function(str, index){
    index == null && (index = str.length - 1);
    return {
      current: function(){
        return str[index];
      },
      atEof: function(){
        return index < 0;
      },
      next: function(){
        return toBackwardsInput(str, index - 1);
      },
      pos: function(){
        return lineAndColumn({
          string: str,
          index: str.length - index
        });
      },
      value: function(){
        return {
          string: str,
          index: index
        };
      }
    };
  };
  pass = function(value, remaining){
    return {
      success: true,
      value: value,
      remaining: remaining
    };
  };
  fail = function(message, lastSuccess, lastValue){
    return {
      success: false,
      message: message,
      lastSuccess: lastSuccess,
      lastValue: lastValue
    };
  };
  withErrorMessage = curry$(function(message, rule, input){
    var res;
    if ((res = rule(input)).success) {
      return res;
    } else {
      return fail(message, res.lastSuccess, res.lastValue);
    }
  });
  simple = curry$(function(test, input){
    var value;
    if (!input.atEof() && test(value = input.current())) {
      return pass(value, input.next());
    } else {
      return fail('simple rule failed', input);
    }
  });
  any = function(){
    var rules;
    rules = slice$.call(arguments);
    if (!rules.length) {
      return simple(function(){
        return true;
      });
    } else {
      return function(input){
        var i$, ref$, len$, rule, res;
        for (i$ = 0, len$ = (ref$ = rules).length; i$ < len$; ++i$) {
          rule = ref$[i$];
          if ((res = rule(input)).success) {
            return res;
          }
        }
        return fail('No rule matched', null, null);
      };
    }
  };
  char = function(c){
    return withErrorMessage("expected '" + c + "'")(
    simple(function(it){
      return it === c;
    }));
  };
  map = curry$(function(convert, rule, input){
    var res;
    if (!(res = rule(input)).success) {
      return res;
    } else {
      return pass(convert(res.value), res.remaining);
    }
  });
  debug = curry$(function(doThis, rule){
    return map(function(it){
      doThis();
      return it;
    })(
    rule);
  });
  $then = curry$(function(second, combine, first, input){
    var res1, res2;
    if ((res1 = first(input)).success) {
      if ((res2 = second(res1.remaining)).success) {
        return pass(combine(res1.value, res2.value), res2.remaining);
      } else {
        return res2;
      }
    } else {
      return res1;
    }
  });
  thenKeep = function(rule){
    return $then(rule, function(x, y){
      return y;
    });
  };
  thenIgnore = function(rule){
    return $then(rule, function(it){
      return it;
    });
  };
  thenConcat = function(rule){
    return $then(rule, curry$(function(x$, y$){
      return x$ + y$;
    }));
  };
  thenNull = function(rule){
    return $then(rule, function(){
      return null;
    });
  };
  thenArrayConcat = function(rule){
    return $then(rule, curry$(function(x$, y$){
      return x$.concat(y$);
    }));
  };
  many = curry$(function(rule, input){
    var output, remaining, res;
    output = [];
    remaining = input;
    while ((res = rule(remaining)).success) {
      output.push(res.value);
      remaining = res.remaining;
    }
    return pass(output, remaining);
  });
  times = curry$(function(count, rule, input){
    var output, remaining, res;
    output = [];
    remaining = input;
    while ((res = rule(remaining)).success && count) {
      output.push(res.value);
      remaining = res.remaining;
      count -= 1;
    }
    if (count) {
      return fail(res.message + " " + count + " more time(s)");
    } else {
      return pass(output, remaining);
    }
  });
  atLeast = curry$(function(count, rule){
    return thenArrayConcat(many(
    rule))(
    times(count)(
    rule));
  });
  atLeastOnce = function(rule){
    return atLeast(1)(
    rule);
  };
  joinString = function(rule){
    return map(function(it){
      return it.join('');
    })(
    rule);
  };
  asArray = function(rule){
    return map(function(it){
      return [it];
    })(
    rule);
  };
  asObjectWithValue = curry$(function(name, rule){
    return map(function(it){
      var obj;
      (obj = {})[name] = it;
      return obj;
    })(
    rule);
  });
  thenSet = curry$(function(name, rule){
    return $then(rule, function(x, y){
      x[name] = y;
      return x;
    });
  });
  sequence = curry$(function(rules, input){
    var remaining, output, i$, len$, r, res;
    remaining = input;
    output = [];
    for (i$ = 0, len$ = rules.length; i$ < len$; ++i$) {
      r = rules[i$];
      if (!(res = r(remaining)).success) {
        return res;
      }
      output.push(res.value);
      remaining = res.remaining;
    }
    return pass(output, res.remaining);
  });
  text = function(value){
    var rules, i$, len$, c;
    rules = [];
    for (i$ = 0, len$ = value.length; i$ < len$; ++i$) {
      c = value[i$];
      rules.push(char(c));
    }
    return joinString(
    sequence(rules));
  };
  maybe = curry$(function(rule, input){
    var res;
    if ((res = rule(input)).success) {
      return res;
    } else {
      return pass(null, input);
    }
  });
  invert = curry$(function(rule, input){
    var res;
    if ((res = rule(input)).success) {
      return fail('unexpected input');
    } else {
      return pass(input.current(), input.next());
    }
  });
  expectEnd = function(input){
    if (input.atEof()) {
      return pass(null, input);
    } else {
      return fail('expected end-of-input', input);
    }
  };
  end = function(rule){
    return thenIgnore(expectEnd)(
    rule);
  };
  delay = curry$(function(getRule, input){
    return getRule()(input);
  });
  always = curry$(function(value, input){
    return pass(value, input);
  });
  alwaysNew = curry$(function(callback, input){
    return pass(callback(), input);
  });
  parse = curry$(function(rule, input){
    var res, message, pos;
    if ((res = rule(input)).success) {
      return res.value;
    } else {
      message = res.message;
      if (res.lastSuccess) {
        pos = res.lastSuccess.pos();
        message = message + " at line " + pos.line + ", column " + pos.column;
      }
      throw new ParseError(message, res.lastSuccess, pos);
    }
  });
  convertRuleToFunction = curry$(function(rule, inputString){
    return parse(
    rule)(
    toInput(inputString));
  });
  lineAndColumn = function(arg$){
    var string, index, lastChar, line, column, i$, x, c;
    string = arg$.string, index = arg$.index;
    lastChar = null;
    line = 1;
    column = 0;
    for (i$ = 0; i$ <= index; ++i$) {
      x = i$;
      c = string.charAt(x);
      column += 1;
      if (c === '\n' || c === '\r') {
        column = 0;
        if (c === '\r' || lastChar !== '\r') {
          line += 1;
        }
      }
      lastChar = c;
    }
    return {
      line: line,
      column: column
    };
  };
  module.exports = {
    toInput: toInput,
    toBackwardsInput: toBackwardsInput,
    pass: pass,
    fail: fail,
    simple: simple,
    withErrorMessage: withErrorMessage,
    any: any,
    char: char,
    map: map,
    debug: debug,
    $then: $then,
    thenKeep: thenKeep,
    thenIgnore: thenIgnore,
    thenConcat: thenConcat,
    thenNull: thenNull,
    thenArrayConcat: thenArrayConcat,
    many: many,
    times: times,
    atLeast: atLeast,
    atLeastOnce: atLeastOnce,
    joinString: joinString,
    asArray: asArray,
    asObjectWithValue: asObjectWithValue,
    thenSet: thenSet,
    sequence: sequence,
    text: text,
    maybe: maybe,
    invert: invert,
    delay: delay,
    end: end,
    always: always,
    alwaysNew: alwaysNew,
    parse: parse,
    convertRuleToFunction: convertRuleToFunction,
    lineAndColumn: lineAndColumn
  };
  function curry$(f, bound){
    var context,
    _curry = function(args) {
      return f.length > 1 ? function(){
        var params = args ? args.concat() : [];
        context = bound ? context || this : this;
        return params.push.apply(params, arguments) <
            f.length && arguments.length ?
          _curry.call(context, params) : f.apply(context, params);
      } : f;
    };
    return _curry();
  }
}).call(this);
