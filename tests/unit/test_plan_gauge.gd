extends TestCase


func test_fills_after_fill_ticks_and_clamps() -> void:
	var gauge := PlanGauge.new(3)
	assert_false(gauge.is_full())
	gauge.tick()
	gauge.tick()
	assert_false(gauge.is_full())
	gauge.tick()
	assert_true(gauge.is_full())
	gauge.tick()
	assert_eq(gauge.ticks, 3)
	assert_eq(gauge.ratio(), 1.0)


func test_reset_empties() -> void:
	var gauge := PlanGauge.new(2)
	gauge.tick()
	gauge.reset()
	assert_eq(gauge.ticks, 0)
	assert_eq(gauge.ratio(), 0.0)


func test_zero_fill_is_always_full() -> void:
	var gauge := PlanGauge.new(0)
	assert_true(gauge.is_full())
	assert_eq(gauge.ratio(), 1.0)
