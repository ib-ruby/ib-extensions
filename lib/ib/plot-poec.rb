require 'distribution'
require 'gnuplot'

## source:  ChatGpt
# Set the variables
s = 100 # current stock price
k = 110 # strike price
t = 0.5 # time to expiry (in years)
r = 0.02 # risk-free interest rate
sigma = 0.2 # implied volatility
p = 0.7 # probability

# Calculate d1 and d2
d1 = (Math.log(s/k) + (r + 0.5*sigma**2)*t) / (sigma * Math.sqrt(t))
d2 = d1 - sigma * Math.sqrt(t)

# Calculate the Z-score for the desired probability
z_score = Distribution::Normal.inv_cdf(p + (1-p)/2)

# Calculate the upper and lower bounds of the 70% probability range
upper_bound = s * Math.exp((r - 0.5*sigma**2)*t + sigma*Math.sqrt(t)*z_score)
lower_bound = s * Math.exp((r - 0.5*sigma**2)*t + sigma*Math.sqrt(t)*(-z_score))

# Create the plot
Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    plot.title 'Probability Density Function with 70% probability range'
    plot.xlabel 'Stock Price'
    plot.ylabel 'Probability Density'

    # Set the x-axis range
    plot.xrange "[#{s*0.6}:#{s*1.4}]"

    # Plot the probability density function
    x = (s*0.6..s*1.4).step(0.1).to_a
    y = x.map { |xi| Distribution::Normal.pdf((Math.log(xi/s) + (r - 0.5*sigma**2)*t) / (sigma * Math.sqrt(t))) / (xi*sigma*Math.sqrt(t))  }
    plot.data << Gnuplot::DataSet.new([x, y]) do |ds|
      ds.with = 'lines'
      ds.linewidth = 2
      ds.linecolor = 'blue'
    end

    # Plot the upper and lower bounds of the 70% probability range
    plot.data << Gnuplot::DataSet.new([lower_bound, 0]) do |ds|
      ds.with = 'lines'
      ds.linewidth = 2
      ds.linecolor = 'red'
    end
    plot.data << Gnuplot::DataSet.new([upper_bound, 0]) do |ds|
      ds.with = 'lines'
      ds.linewidth = 2
      ds.linecolor = 'red'
    end
    plot.data << Gnuplot::DataSet.new([[lower_bound, upper_bound], [0, 0]]) do |ds|
      ds.with = 'filledcurve x1=1 x2=2'
      ds.fillcolor = 'red'
      ds.fillstyle = 'transparent solid 0.2'
    end
  end
end
