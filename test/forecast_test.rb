require_relative "test_helper"

class ForecastTest < Minitest::Test
  def test_daily
    series = {}
    date = Date.parse("2018-04-01")
    38.times do
      series[date] = date.wday
      date += 1
    end

    expected = series.to_a.last(10).to_h
    predicted = Prophet.forecast(series.first(28).to_h)
    assert_equal expected.keys, predicted.keys
    assert_elements_in_delta expected.values, predicted.values
  end

  def test_delta_zero
    series = {}
    date = Date.parse("2018-04-01")
    38.times do |n|
      series[date - n] = 9.99
    end

    expected = series.to_a.last(10).to_h
    predicted = Prophet.forecast(series.first(28).to_h)
    assert_equal expected.keys, predicted.keys
    assert_elements_in_delta expected.values, predicted.values
  end

  def test_weekly
    series = {}
    date = Date.parse("2018-04-01")
    62.times do |i|
      series[date] = i % 2
      date += 7
    end

    expected = series.to_a.last(10).to_h
    predicted = Prophet.forecast(series.first(52).to_h)
    assert_equal expected.keys, predicted.keys
  end

  def test_monthly
    series = {}
    34.times do |i|
      date = Date.new(2018 + (i / 12), i % 12 + 1, 1)
      series[date] = i % 2
    end

    expected = series.to_a.last(10).to_h
    predicted = Prophet.forecast(series.first(24).to_h)
    assert_equal expected.keys, predicted.keys
  end

  def test_quarterly
    series = {}
    30.times do |i|
      date = Date.new(2000 + i / 4, (i % 4) * 3 + 1)
      series[date] = i % 2
    end

    expected = series.to_a.last(10).to_h
    predicted = Prophet.forecast(series.first(20).to_h)
    assert_equal expected.keys, predicted.keys
  end

  def test_yearly
    series = {}
    30.times do |i|
      date = Date.new(1970 + i)
      series[date] = i % 2
    end

    expected = series.to_a.last(10).to_h
    predicted = Prophet.forecast(series.first(20).to_h)
    assert_equal expected.keys, predicted.keys
  end

  def test_count
    series = {}
    date = Date.parse("2018-04-01")
    31.times do
      series[date] = date.wday
      date += 1
    end

    expected = series.to_a.last(3).to_h
    predicted = Prophet.forecast(series.first(28).to_h, count: 3)
    assert_equal expected.keys, predicted.keys
    assert_elements_in_delta expected.values, predicted.values
  end

  def test_bad_key
    series = {}
    10.times do |i|
      series[i] = i
    end

    error = assert_raises(ArgumentError) do
      Prophet.forecast(series)
    end
    assert_equal "Expected Date, got Integer", error.message
  end

  def test_few_data_points
    error = assert_raises(ArgumentError) do
      Prophet.forecast({})
    end
    assert_equal "Series must have at least 10 data points", error.message
  end
end
