module.exports = {
    url: 'http://localhost:5001/swagger/v1/swagger.json',
    output: './api/generated',
    templates: './api/templates',
    httpClientType: 'axios',
    defaultResponseAsSuccess: false,
    generateClient: true,
    generateRouteTypes: true,
    generateResponses: true,
    toJS: false,
    extractRequestParams: true,
    extractRequestBody: true,
    prettier: {
        printWidth: 120,
        tabWidth: 2,
        singleQuote: true,
        trailingComma: 'all',
    },
    hooks: {
        onCreateRoute: (routeData) => {
            // Custom transformation ถ้าต้องการ
            return routeData;
        },
    },
};