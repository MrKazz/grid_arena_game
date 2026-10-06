class_name TestCase
extends RefCounted
## Minimal base class for tests. Every method named test_* is run on a
## fresh instance. Tests may be coroutines (use `await`) and can reach the
## SceneTree through `tree`.

var tree: SceneTree
var failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("expected true%s" % _suffix(message))


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("expected false%s" % _suffix(message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _equal(actual, expected):
		fail("expected %s, got %s%s" % [var_to_str(expected), var_to_str(actual), _suffix(message)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _equal(actual, unexpected):
		fail("did not expect %s%s" % [var_to_str(unexpected), _suffix(message)])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("expected null, got %s%s" % [var_to_str(value), _suffix(message)])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected non-null%s" % _suffix(message))


func _equal(a: Variant, b: Variant) -> bool:
	# Compare Arrays by content regardless of typed/untyped.
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equal(a[i], b[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func _suffix(message: String) -> String:
	return "" if message.is_empty() else " (%s)" % message
