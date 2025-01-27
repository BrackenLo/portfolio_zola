+++
title = "Shadertoy Implementation"

[taxonomies]
tags = ["Rust", "Wgpu", "Graphics"]

[extra]
date = "2022"
img = "icon.gif"
+++

Translation of a cool [shader found on shadertoy](https://www.shadertoy.com/view/tdG3Rd) from GLSL to WGSL.

Done while still learning WGPU and as such project structure is still very heavily based on the [learn WGPU
](https://sotrh.github.io/learn-wgpu/) tutorial.


<img src="shadertoy.gif" />

The version of WGSL is very outdate compared to current WGSL.

{{ collapsible(text='Toggle "shader.wgsl') }}
{{ embed_code_block(language="wgsl", path="content/projects/shadertoy-implement/code/shader.wgsl") }}

<br>


{{ collapsible(text='Toggle "main.rs') }}
{{ embed_code_block(language="rust", path="content/projects/shadertoy-implement/code/main.rs") }}

{{ collapsible(text='Toggle "state.rs') }}
{{ embed_code_block(language="rust", path="content/projects/shadertoy-implement/code/state.rs") }}

{{ collapsible(text='Toggle "draw.rs') }}
{{ embed_code_block(language="rust", path="content/projects/shadertoy-implement/code/draw.rs") }}

{{ collapsible(text='Toggle "model.rs') }}
{{ embed_code_block(language="rust", path="content/projects/shadertoy-implement/code/model.rs") }}

