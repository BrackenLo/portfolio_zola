{%- set file = load_data(path= path) -%}

```{{ language }}, linenos, linenostart=1
{{ file | safe }}
```
