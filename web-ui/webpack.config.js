var path = require('path');
var webpack = require('webpack');

module.exports = {
  devtool: 'eval',
  entry: [
    'webpack-dev-server/client?http://localhost:3000',
    'webpack/hot/only-dev-server',
    './src/index'
  ],
  output: {
    path: path.join(__dirname, 'dist'),
    filename: 'boardgame.bundle.js',
    publicPath: '/static/'
  },
  plugins: [
    new webpack.HotModuleReplacementPlugin()
  ],
  module: {
    rules: [{
      test: /\.js$/,
      use: ['react-hot-loader/webpack', 'babel-loader'],
      exclude: /node_modules/,
      include: path.join(__dirname, 'src')
    },
    {
      test: /\.json$/,
      use: "json-loader"
    }
    ]
  }
};
