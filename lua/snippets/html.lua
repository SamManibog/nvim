return {
    s("new", {
        t({
            "<!DOCTYPE html>",
            "<html lang=\"en\">",
            "\t<head>",
            "\t\t<meta charset=\"UTF-8\">",
            "\t\t<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
            "\t\t<title>",
        }),
        i(1, "Document"),
        t({
            "</title>",
            "\t</head>",
            "\t<body>",
            "\t\t",
        }),
        i(0),
        t({
            "",
            "\t</body>",
            "</html>",
        })
    }),
    s("stylesheet",
        fmt("<link rel=\"stylesheet\" type=\"text/css\" href=\"{}\">", {
            i(1, "style.css"),
        })
    )
}, {}
