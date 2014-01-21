(function(){
  var toInput, inputNext, inputAtEof, inputCurrentLetter, pass, fail, withErrorMessage, simple, any, char, map, debug, $then, thenKeep, thenIgnore, thenConcat, thenNull, thenArrayConcat, $or, anyOf, many, times, joinString, atLeastOnce, sequence, text, maybe, except, doUntil, expectEnd, end, delay, always, parse, convertRuleToFunction, lineAndColumn;
  toInput = function(str){
    return {
      string: str,
      index: 0
    };
  };
  inputNext = function(arg$){
    var string, index;
    string = arg$.string, index = arg$.index;
    return {
      string: string,
      index: index + 1
    };
  };
  inputAtEof = function(arg$){
    var string, index;
    string = arg$.string, index = arg$.index;
    return index >= string.length;
  };
  inputCurrentLetter = function(arg$){
    var string, index;
    string = arg$.string, index = arg$.index;
    return string.charAt(index);
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
    if (!inputAtEof(input) && test(value = inputCurrentLetter(input))) {
      return pass(value, inputNext(input));
    } else {
      return fail('simple rule failed', input);
    }
  });
  any = function(){
    return simple(function(){
      return true;
    });
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
    return $then(rule, function(x, y){
      return x;
    });
  };
  thenConcat = function(rule){
    return $then(rule, function(x, y){
      return x + y;
    });
  };
  thenNull = function(rule){
    return $then(rule, function(){
      return null;
    });
  };
  thenArrayConcat = function(rule){
    return $then(rule, function(x, y){
      return x.concat(y);
    });
  };
  $or = curry$(function(second, first, input){
    var res1, res2;
    if ((res1 = first(input)).success) {
      return res1;
    } else {
      if ((res2 = second(input)).success) {
        return res2;
      } else {
        return fail(res1.message + " or " + res2.message, input);
      }
    }
  });
  anyOf = curry$(function(rules, input){
    var i$, len$, r, res;
    for (i$ = 0, len$ = rules.length; i$ < len$; ++i$) {
      r = rules[i$];
      if ((res = r(input)).success) {
        return res;
      }
    }
    return fail('any-of failed', input);
  });
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
  joinString = function(rule){
    return map(function(it){
      return it.join('');
    })(
    rule);
  };
  atLeastOnce = function(rule){
    return thenArrayConcat(many(rule))(
    map(function(it){
      return [it];
    })(
    rule));
  };
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
  except = curry$(function(bad, rule, input){
    if (bad(input).success) {
      return fail('except matched', input);
    } else {
      return rule(input);
    }
  });
  doUntil = curry$(function(bad, rule){
    return many(
    except(bad)(
    rule));
  });
  expectEnd = function(input){
    if (inputAtEof(input)) {
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
  parse = curry$(function(rule, input){
    var res;
    if ((res = rule(input)).success) {
      return res.value;
    } else {
      return false;
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
    inputNext: inputNext,
    inputAtEof: inputAtEof,
    inputCurrentLetter: inputCurrentLetter,
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
    $or: $or,
    anyOf: anyOf,
    many: many,
    times: times,
    joinString: joinString,
    atLeastOnce: atLeastOnce,
    sequence: sequence,
    text: text,
    maybe: maybe,
    except: except,
    doUntil: doUntil,
    delay: delay,
    end: end,
    always: always,
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
