const path = require("path");
const glob = require("glob");
const TerserPlugin = require("terser-webpack-plugin");
const OptimizeCSSAssetsPlugin = require("optimize-css-assets-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");
const RemovePlugin = require("remove-files-webpack-plugin");

module.exports = (env, options) => ({
  optimization: {
    minimizer: [
      new TerserPlugin({ cache: true, parallel: true, sourceMap: false }),
      new OptimizeCSSAssetsPlugin({}),
    ],
  },
  entry: {
    app: glob.sync("./vendor/**/*.js").concat(["./js/app.js"]),
    light: path.resolve(__dirname, "./css/light.scss"),
    dark: path.resolve(__dirname, "./css/dark.scss"),
  },
  output: {
    filename: "[name].js",
    path: path.resolve(__dirname, "../priv/static/js"),
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
        },
      },
      {
        test: /\.s?css$/,
        use: [
          {
            loader: "file-loader",
            options: {
              name: "[name].css",
              context: "./",
              outputPath: "../css",
              publicPath: path.resolve(__dirname, "../priv/static/css"),
            },
          },
          {
            loader: "extract-loader",
          },
          {
            loader: "css-loader",
          },
          {
            loader: "sass-loader",
            options: {
              sourceMap: true,
            },
          },
        ],
      },
    ],
  },
  plugins: [
    new CopyWebpackPlugin([{ from: "static/", to: "../" }]),
    new RemovePlugin({
      after: {
        root: path.resolve(__dirname, "../priv/static/js"),
        include: ["light.js", "dark.js"],
      },
    }),
  ],
});
