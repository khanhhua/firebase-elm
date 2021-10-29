var path = require("path");
var HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
    entry: {
        // main: [
        //     './src/index.js'
        // ],
        lib: './lib/Firebase.js'
    },
    output: {
        path: path.resolve(__dirname + '/dist'),
        filename: '[name].js',
        library: {
            type: "umd",
            name: "Firebase",
        },
    },
    module: {
        rules: [
            {
                test: /\.(css|scss)$/,
                use: [
                    'style-loader',
                    'css-loader',
                ],
                generator: {
                    filename: '[name]-[contenthash][ext]'
                }
            },
            {
                test: /\.html$/,
                exclude: /node_modules/,
                loader: 'html-loader',
            },
            {
                test: /\.elm$/,
                exclude: [/elm-stuff/, /node_modules/],
                loader: 'elm-webpack-loader',
            },
        ],
        noParse: /\.elm$/,
    },
    // plugins: [
    //     new HtmlWebpackPlugin({
    //         template: 'src/index.html',
    //     })
    // ],
    devServer: {
        inline: true,
        stats: { colors: true },
    },
    mode: "development"
};
