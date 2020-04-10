# Prophet.rb

Time series forecasting for Ruby, ported from [Prophet](https://github.com/facebook/prophet)

Supports:

- Multiple seasonalities
- Linear and non-linear growth
- Holidays and special events

And gracefully handles missing data

[![Build Status](https://travis-ci.org/ankane/prophet.svg?branch=master)](https://travis-ci.org/ankane/prophet)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'prophet-rb'
```

## Documentation

Check out the [Prophet documentation](https://facebook.github.io/prophet/docs/quick_start.html) for a great explanation of all of the features. The Ruby API follows the Python API and supports the same features.

## Quick Start

[Explanation](https://facebook.github.io/prophet/docs/quick_start.html)

Create a data frame with `ds` and `y` columns - here’s [an example](examples/example_wp_log_peyton_manning.csv) you can use

```ruby
df = Daru::DataFrame.from_csv("example_wp_log_peyton_manning.csv")
df.head(5)
```

ds | y
--- | ---
2007-12-10 | 9.59076113
2007-12-11 | 8.51959031
2007-12-12 | 8.18367658
2007-12-13 | 8.07246736
2007-12-14 | 7.89357207

Fit a model

```ruby
m = Prophet.new
m.fit(df)
```

Make a data frame with a `ds` column for future predictions

```ruby
future = m.make_future_dataframe(periods: 365)
future.tail(5)
```

ds |
--- |
2017-01-15 |
2017-01-16 |
2017-01-17 |
2017-01-18 |
2017-01-19 |

Make predictions

```ruby
forecast = m.predict(future)
forecast["ds", "yhat", "yhat_lower", "yhat_upper"].tail(5)
```

ds | yhat | yhat_lower | yhat_upper
--- | --- | --- | ---
2017-01-15 | 8.21192840 | 7.52526442 | 8.92389960
2017-01-16 | 8.53696359 | 7.79124970 | 9.22620028
2017-01-17 | 8.32439891 | 7.62482699 | 9.04719328
2017-01-18 | 8.15702395 | 7.40079968 | 8.91301650
2017-01-19 | 8.16900433 | 7.45673678 | 8.83486188

## Plots

For plots, install the [matplotlib](https://github.com/mrkn/matplotlib.rb) gem.

Plot the forecast

```ruby
m.plot(forecast).savefig("forecast.png")
```

![Forecast](https://blazer.dokkuapp.com/assets/prophet/forecast-a9d43195b8ad23703eda7bb8b52b8a758efb4699e2313f32d7bbdfaa2f4275f6.png)

Plot components

```ruby
m.plot_components(forecast).savefig("components.png")
```

![Components](https://blazer.dokkuapp.com/assets/prophet/components-b9e31bfcf77e57bbd503c0bcff5e5544e66085b90709b06dd96c5f622a87d84f.png)

## Saturating Forecasts

[Explanation](https://facebook.github.io/prophet/docs/saturating_forecasts.html)

Forecast logistic growth instead of linear

```ruby
df = Daru::DataFrame.from_csv("example_wp_log_R.csv")
df["cap"] = 8.5
m = Prophet.new(growth: "logistic")
m.fit(df)
future = m.make_future_dataframe(periods: 365)
future["cap"] = 8.5
forecast = m.predict(future)
```

## Trend Changepoints

[Explanation](https://facebook.github.io/prophet/docs/trend_changepoints.html)

Specify the location of changepoints

```ruby
m = Prophet.new(changepoints: ["2014-01-01"])
```

## Holidays and Special Events

[Explanation](https://facebook.github.io/prophet/docs/seasonality,_holiday_effects,_and_regressors.html)

Create a data frame with `holiday` and `ds` columns. Include all occurrences in your past data and future occurrences you’d like to forecast.

```ruby
playoffs = Daru::DataFrame.new(
  "holiday" => ["playoff"] * 14,
  "ds" => ["2008-01-13", "2009-01-03", "2010-01-16",
           "2010-01-24", "2010-02-07", "2011-01-08",
           "2013-01-12", "2014-01-12", "2014-01-19",
           "2014-02-02", "2015-01-11", "2016-01-17",
           "2016-01-24", "2016-02-07"],
  "lower_window" => [0] * 14,
  "upper_window" => [1] * 14
)
superbowls = Daru::DataFrame.new(
  "holiday" => ["superbowl"] * 3,
  "ds" => ["2010-02-07", "2014-02-02", "2016-02-07"],
  "lower_window" => [0] * 3,
  "upper_window" => [1] * 3
)
holidays = playoffs.concat(superbowls)

m = Prophet.new(holidays: holidays)
m.fit(df)
```

Add country-specific holidays

```ruby
m = Prophet.new
m.add_country_holidays(country_name: "US")
m.fit(df)
```

Specify custom seasonalities

```ruby
m = Prophet.new(weekly_seasonality: false)
m.add_seasonality(name: "monthly", period: 30.5, fourier_order: 5)
forecast = m.fit(df).predict(future)
```

## Multiplicative Seasonality

[Explanation](https://facebook.github.io/prophet/docs/multiplicative_seasonality.html)

```ruby
df = Daru::DataFrame.from_csv("example_air_passengers.csv")
m = Prophet.new(seasonality_mode: "multiplicative")
m.fit(df)
future = m.make_future_dataframe(periods: 50, freq: "MS")
forecast = m.predict(future)
```

## Non-Daily Data

[Explanation](https://facebook.github.io/prophet/docs/non-daily_data.html)

Sub-daily data

```ruby
df = Daru::DataFrame.from_csv("example_yosemite_temps.csv")
m = Prophet.new(changepoint_prior_scale: 0.01).fit(df)
future = m.make_future_dataframe(periods: 300, freq: "H")
forecast = m.predict(future)
```

## Resources

- [Forecasting at Scale](https://peerj.com/preprints/3190.pdf)

## Credits

This library was ported from the [Prophet Python library](https://github.com/facebook/prophet) and is available under the same license.

## History

View the [changelog](https://github.com/ankane/prophet/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/prophet/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/prophet/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/ankane/prophet.git
cd prophet
bundle install
bundle exec ruby ext/prophet/extconf.rb
bundle exec rake test
```
