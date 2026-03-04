const path = require('path');

module.exports = {
    content: [
        '../aspnetcore/**/*.cshtml',
        './hub/**/*.{vue,js,ts,jsx,tsx}',
        './apollo/**/*.{vue,js,ts,jsx,tsx}',
        './css/**/*.{css,scss}',
        './index.html',
    ],
    theme: {
        extend: {
            fontFamily: {
                'sarabun': ['"THSarabunNew"', 'sans-serif'],
                'swu': ['"Srinakharinwirot"', 'sans-serif'],
            },
        },
    },
    plugins: [
        require('daisyui'),
        require('@tailwindcss/forms'),
        require('@tailwindcss/typography'),
    ],
    daisyui: {
        themes: ["light"],
        darkTheme: false,
        base: true,
        styled: true,
        utils: true,
        logs: false,
    }
}