module Prophet
  module Plot
    def plot(fcst, ax: nil, uncertainty: true, plot_cap: true, xlabel: "ds", ylabel: "y", figsize: [10, 6])
      if ax.nil?
        fig = plt.figure(facecolor: "w", figsize: figsize)
        ax = fig.add_subplot(111)
      else
        fig = ax.get_figure
      end
      fcst_t = to_pydatetime(fcst["ds"])
      ax.plot(to_pydatetime(@history["ds"]), @history["y"].map(&:to_f), "k.")
      ax.plot(fcst_t, fcst["yhat"].map(&:to_f), ls: "-", c: "#0072B2")
      if fcst.vectors.include?("cap") && plot_cap
        ax.plot(fcst_t, fcst["cap"].map(&:to_f), ls: "--", c: "k")
      end
      if @logistic_floor && fcst.vectors.include?("floor") && plot_cap
        ax.plot(fcst_t, fcst["floor"].map(&:to_f), ls: "--", c: "k")
      end
      if uncertainty && @uncertainty_samples
        ax.fill_between(fcst_t, fcst["yhat_lower"].map(&:to_f), fcst["yhat_upper"].map(&:to_f), color: "#0072B2", alpha: 0.2)
      end
      # Specify formatting to workaround matplotlib issue #12925
      locator = dates.AutoDateLocator.new(interval_multiples: false)
      formatter = dates.AutoDateFormatter.new(locator)
      ax.xaxis.set_major_locator(locator)
      ax.xaxis.set_major_formatter(formatter)
      ax.grid(true, which: "major", c: "gray", ls: "-", lw: 1, alpha: 0.2)
      ax.set_xlabel(xlabel)
      ax.set_ylabel(ylabel)
      fig.tight_layout
      fig
    end

    def plot_components(fcst, uncertainty: true, plot_cap: true, weekly_start: 0, yearly_start: 0, figsize: nil)
      components = ["trend"]
      if @train_holiday_names && fcst.vectors.include?("holidays")
        components << "holidays"
      end
      # Plot weekly seasonality, if present
      if @seasonalities["weekly"] && fcst.vectors.include?("weekly")
        components << "weekly"
      end
      # Yearly if present
      if @seasonalities["yearly"] && fcst.vectors.include?("yearly")
        components << "yearly"
      end
      # Other seasonalities
      components.concat(@seasonalities.keys.select { |name| fcst.vectors.include?(name) && !["weekly", "yearly"].include?(name) }.sort)
      regressors = {"additive" => false, "multiplicative" => false}
      @extra_regressors.each do |name, props|
        regressors[props[:mode]] = true
      end
      ["additive", "multiplicative"].each do |mode|
        if regressors[mode] && fcst.vectors.include?("extra_regressors_#{mode}")
          components << "extra_regressors_#{mode}"
        end
      end
      npanel = components.size

      figsize = figsize || [9, 3 * npanel]
      fig, axes = plt.subplots(npanel, 1, facecolor: "w", figsize: figsize)

      if npanel == 1
        axes = [axes]
      end

      multiplicative_axes = []

      axes.tolist.zip(components) do |ax, plot_name|
        if plot_name == "trend"
          plot_forecast_component(fcst, "trend", ax: ax, uncertainty: uncertainty, plot_cap: plot_cap)
        elsif @seasonalities[plot_name]
          if plot_name == "weekly" || @seasonalities[plot_name][:period] == 7
            plot_weekly(name: plot_name, ax: ax, uncertainty: uncertainty, weekly_start: weekly_start)
          elsif plot_name == "yearly" || @seasonalities[plot_name][:period] == 365.25
            plot_yearly(name: plot_name, ax: ax, uncertainty: uncertainty, yearly_start: yearly_start)
          else
            plot_seasonality(name: plot_name, ax: ax, uncertainty: uncertainty)
          end
        elsif ["holidays", "extra_regressors_additive", "extra_regressors_multiplicative"].include?(plot_name)
          plot_forecast_component(fcst, plot_name, ax: ax, uncertainty: uncertainty, plot_cap: false)
        end
        if @component_modes["multiplicative"].include?(plot_name)
          multiplicative_axes << ax
        end
      end

      fig.tight_layout
      # Reset multiplicative axes labels after tight_layout adjustment
      multiplicative_axes.each do |ax|
        ax = set_y_as_percent(ax)
      end
      fig
    end

    private

    def plot_forecast_component(fcst, name, ax: nil, uncertainty: true, plot_cap: false, figsize: [10, 6])
      artists = []
      if !ax
        fig = plt.figure(facecolor: "w", figsize: figsize)
        ax = fig.add_subplot(111)
      end
      fcst_t = to_pydatetime(fcst["ds"])
      artists += ax.plot(fcst_t, fcst[name].map(&:to_f), ls: "-", c: "#0072B2")
      if fcst.vectors.include?("cap") && plot_cap
        artists += ax.plot(fcst_t, fcst["cap"].map(&:to_f), ls: "--", c: "k")
      end
      if @logistic_floor && fcst.vectors.include?("floor") && plot_cap
        ax.plot(fcst_t, fcst["floor"].map(&:to_f), ls: "--", c: "k")
      end
      if uncertainty && @uncertainty_samples
        artists += [ax.fill_between(fcst_t, fcst[name + "_lower"].map(&:to_f), fcst[name + "_upper"].map(&:to_f), color: "#0072B2", alpha: 0.2)]
      end
      # Specify formatting to workaround matplotlib issue #12925
      locator = dates.AutoDateLocator.new(interval_multiples: false)
      formatter = dates.AutoDateFormatter.new(locator)
      ax.xaxis.set_major_locator(locator)
      ax.xaxis.set_major_formatter(formatter)
      ax.grid(true, which: "major", c: "gray", ls: "-", lw: 1, alpha: 0.2)
      ax.set_xlabel("ds")
      ax.set_ylabel(name)
      if @component_modes["multiplicative"].include?(name)
        ax = set_y_as_percent(ax)
      end
      artists
    end

    def seasonality_plot_df(ds)
      df_dict = {"ds" => ds, "cap" => [1.0] * ds.size, "floor" => [0.0] * ds.size}
      @extra_regressors.each do |name|
        df_dict[name] = [0.0] * ds.size
      end
      # Activate all conditional seasonality columns
      @seasonalities.values.each do |props|
        if props[:condition_name]
          df_dict[props[:condition_name]] = [true] * ds.size
        end
      end
      df = Daru::DataFrame.new(df_dict)
      df = setup_dataframe(df)
      df
    end

    def plot_weekly(ax: nil, uncertainty: true, weekly_start: 0, figsize: [10, 6], name: "weekly")
      artists = []
      if !ax
        fig = plt.figure(facecolor: "w", figsize: figsize)
        ax = fig.add_subplot(111)
      end
      # Compute weekly seasonality for a Sun-Sat sequence of dates.
      start = Date.parse("2017-01-01")
      days = 7.times.map { |i| start + i + weekly_start }
      df_w = seasonality_plot_df(days)
      seas = predict_seasonal_components(df_w)
      days = days.map { |v| v.strftime("%A") }
      artists += ax.plot(days.size.times.to_a, seas[name].map(&:to_f), ls: "-", c: "#0072B2")
      if uncertainty && @uncertainty_samples
        artists += [ax.fill_between(days.size.times.to_a, seas[name + "_lower"].map(&:to_f), seas[name + "_upper"].map(&:to_f), color: "#0072B2", alpha: 0.2)]
      end
      ax.grid(true, which: "major", c: "gray", ls: "-", lw: 1, alpha: 0.2)
      ax.set_xticks(days.size.times.to_a)
      ax.set_xticklabels(days)
      ax.set_xlabel("Day of week")
      ax.set_ylabel(name)
      if @seasonalities[name]["mode"] == "multiplicative"
        ax = set_y_as_percent(ax)
      end
      artists
    end

    def plot_yearly(ax: nil, uncertainty: true, yearly_start: 0, figsize: [10, 6], name: "yearly")
      artists = []
      if !ax
        fig = plt.figure(facecolor: "w", figsize: figsize)
        ax = fig.add_subplot(111)
      end
      # Compute yearly seasonality for a Jan 1 - Dec 31 sequence of dates.
      start = Date.parse("2017-01-01")
      days = 365.times.map { |i| start + i + yearly_start }
      df_y = seasonality_plot_df(days)
      seas = predict_seasonal_components(df_y)
      artists += ax.plot(to_pydatetime(df_y["ds"]), seas[name].map(&:to_f), ls: "-", c: "#0072B2")
      if uncertainty && @uncertainty_samples
        artists += [ax.fill_between(to_pydatetime(df_y["ds"]), seas[name + "_lower"].map(&:to_f), seas[name + "_upper"].map(&:to_f), color: "#0072B2", alpha: 0.2)]
      end
      ax.grid(true, which: "major", c: "gray", ls: "-", lw: 1, alpha: 0.2)
      months = dates.MonthLocator.new((1..12).to_a, bymonthday: 1, interval: 2)
      ax.xaxis.set_major_formatter(ticker.FuncFormatter.new(lambda { |x, pos=nil| dates.num2date(x).strftime("%B %-e") }))
      ax.xaxis.set_major_locator(months)
      ax.set_xlabel("Day of year")
      ax.set_ylabel(name)
      if @seasonalities[name][:mode] == "multiplicative"
        ax = set_y_as_percent(ax)
      end
      artists
    end

    def plot_seasonality(name:, ax: nil, uncertainty: true, figsize: [10, 6])
      artists = []
      if !ax
        fig = plt.figure(facecolor: "w", figsize: figsize)
        ax = fig.add_subplot(111)
      end
      # Compute seasonality from Jan 1 through a single period.
      start = Time.utc(2017)
      period = @seasonalities[name][:period]
      finish = start + period * 86400
      plot_points = 200
      start = start.to_i
      finish = finish.to_i
      step = (finish - start) / (plot_points - 1).to_f
      days = plot_points.times.map { |i| Time.at(start + i * step).utc }
      df_y = seasonality_plot_df(days)
      seas = predict_seasonal_components(df_y)
      artists += ax.plot(to_pydatetime(df_y["ds"]), seas[name].map(&:to_f), ls: "-", c: "#0072B2")
      if uncertainty && @uncertainty_samples
        artists += [ax.fill_between(to_pydatetime(df_y["ds"]), seas[name + "_lower"].map(&:to_f), seas[name + "_upper"].map(&:to_f), color: "#0072B2", alpha: 0.2)]
      end
      ax.grid(true, which: "major", c: "gray", ls: "-", lw: 1, alpha: 0.2)
      step = (finish - start) / (7 - 1).to_f
      xticks = to_pydatetime(7.times.map { |i| Time.at(start + i * step).utc })
      ax.set_xticks(xticks)
      if period <= 2
        fmt_str = "%T"
      elsif period < 14
        fmt_str = "%m/%d %R"
      else
        fmt_str = "%m/%d"
      end
      ax.xaxis.set_major_formatter(ticker.FuncFormatter.new(lambda { |x, pos=nil| dates.num2date(x).strftime(fmt_str) }))
      ax.set_xlabel("ds")
      ax.set_ylabel(name)
      if @seasonalities[name][:mode] == "multiplicative"
        ax = set_y_as_percent(ax)
      end
      artists
    end

    def set_y_as_percent(ax)
      yticks = 100 * ax.get_yticks
      yticklabels = yticks.tolist.map { |y| "%.4g%%" % y }
      ax.set_yticklabels(yticklabels)
      ax
    end

    def plt
      begin
        require "matplotlib/pyplot"
      rescue LoadError
        raise Error, "Install the matplotlib gem for plots"
      end
      Matplotlib::Pyplot
    end

    def dates
      PyCall.import_module("matplotlib.dates")
    end

    def ticker
      PyCall.import_module("matplotlib.ticker")
    end

    def to_pydatetime(v)
      datetime = PyCall.import_module("datetime")
      v.map { |v| datetime.datetime.utcfromtimestamp(v.to_i) }
    end
  end
end