//====================================================================
//Vertex Shader

struct VertexIn {
    [[location(0)]] pos: vec3<f32>;
};

struct InstanceInput {
    [[location(5)]] model_matrix_0: vec4<f32>;
    [[location(6)]] model_matrix_1: vec4<f32>;
    [[location(7)]] model_matrix_2: vec4<f32>;
    [[location(8)]] model_matrix_3: vec4<f32>;
};

struct VertexOutput {
    [[builtin(position)]] clip_position: vec4<f32>;
    [[location(0)]] coord: vec3<f32>;
};

//--------------------------------------------------

[[stage(vertex)]]
fn vs_main(
    model: VertexIn,
    instance: InstanceInput,
) -> VertexOutput {

    let model_matrix = mat4x4<f32>(
        instance.model_matrix_0,
        instance.model_matrix_1,
        instance.model_matrix_2,
        instance.model_matrix_3,
    );

    var out: VertexOutput;
    out.clip_position = model_matrix * vec4<f32>(model.pos, 1.0);
    out.coord = model.pos;
    return out;
}

//====================================================================
//Fragment Shader

struct Time {
    elapsed: f32;
};
[[group(0), binding(0)]]
var<uniform> u_time: Time;

//--------------------------------------------------

struct Size {
    size: vec2<f32>;
};
[[group(1), binding(0)]]
var<uniform> u_size: Size;

//--------------------------------------------------

fn colormap_red(x: f32) -> f32 {
    if (x < 0.0) {
        return 54.0 / 255.0;
    } else if (x < 20049.0 / 82979.0) {
        return (829.79 * x + 54.51) / 255.0;
    } else {
        return 1.0;
    }
}

fn colormap_green(x: f32) -> f32 {
    if (x < 20049.0 / 82979.0) {
        return 0.0;
    } else if (x < 327013.0 / 810990.0) {
        return (8546482679670.0 / 10875673217.0 * x - 2064961390770.0 / 10875673217.0) / 255.0;
    } else if (x <= 1.0) {
        return (103806720.0 / 483977.0 * x + 19607415.0 / 483977.0) / 255.0;
    } else {
        return 1.0;
    }
}

fn colormap_blue(x: f32) -> f32 {
    if (x < 0.0) {
        return 54.0 / 255.0;
    } else if (x < 7249.0 / 82979.0) {
        return (829.79 * x + 54.51) / 255.0;
    } else if (x < 20049.0 / 82979.0) {
        return 127.0 / 255.0;
    } else if (x < 327013.0 / 810990.0) {
        return (792.02249341361393720147485376583 * x - 64.364790735602331034989206222672) / 255.0;
    } else {
        return 1.0;
    }
}

fn colormap(x: f32) -> vec4<f32> {
    return vec4<f32>(colormap_red(x), colormap_green(x), colormap_blue(x), 1.0);
}


fn rand(n: vec2<f32>) -> f32 { 
    return fract(sin(dot(n, vec2<f32>(12.9898, 4.1414))) * 43758.5453);
}

fn noise(p: vec2<f32>) -> f32 {
    let ip = floor(p);
    let u = fract(p);
    let u = u*u*(3.0-(2.0*u));

    let res = mix(
        mix(rand(ip),rand(ip + vec2<f32>(1.0, 0.0)), u.x),
        mix(rand(ip + vec2<f32>(0.0, 1.0)), rand(ip + vec2<f32>(1.0, 1.0)), u.x), u.y);
    return res*res;
}

fn fbm(p: vec2<f32> ) -> f32 {

    let mtx = mat2x2<f32>(
        0.8, 0.6,
        -0.6, 0.8,
    );


    let f = 0.0;

    let f = f + 0.500000 * noise( p + u_time.elapsed  ); 
    let p = mtx * p * 2.02;

    let f = f + 0.031250*noise( p ); 
    let p = mtx*p*2.01;

    let f = f + 0.250000*noise( p ); 
    let p = mtx*p*2.03;

    let f = f + 0.125000*noise( p ); 
    let p = mtx*p*2.01;

    let f = f + 0.062500*noise( p ); 
    let p = mtx*p*2.04;

    let f = f + 0.015625 * noise( p + sin(u_time.elapsed) );

    return f/0.96875;
}

fn pattern(p: vec2<f32> ) -> f32 {
	return fbm( p + fbm( p + fbm( p ) ) );
}


[[stage(fragment)]]
fn fs_main(
    in: VertexOutput,
) -> [[location(0)]] vec4<f32> {

    let uv = in.clip_position.xy / u_size.size;

    let time = u_time.elapsed;

    //let x = cos(time + in.coord.x);
    //let y = cos(time + in.coord.y + 2.);
    //let z = cos(time + in.coord.z + 4.);

    //let x = cos(time + uv.x);
    //let y = cos(time + uv.y + 2.);
    //let z = cos(time + uv.x + 4.);

    //let col = 0.5 + 0.5 * vec3<f32>(x, y, z);
    //return vec4<f32>(col, 1.0);


    let shade = pattern(uv);
    let fragColor = vec4<f32>(colormap(shade).rgb, shade);
    return fragColor;
}

//====================================================================
