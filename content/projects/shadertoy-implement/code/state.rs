//====================================================================

use wgpu::util::DeviceExt;
use winit::{
    event::*,
    window::Window
};

use crate::{
    model::{VERTICES, Vertex}, 
    draw::{self, ShapeDrawer, HasInstanceBuffer}
};

//====================================================================

pub struct State {
    surface: wgpu::Surface,
    device: wgpu::Device,
    queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    size: winit::dpi::PhysicalSize<u32>,

    render_pipeline: wgpu::RenderPipeline,
    vertex_buffer: wgpu::Buffer,

    time: std::time::Instant,
    time_current: f32,
    time_buffer: wgpu::Buffer,
    time_bind_group: wgpu::BindGroup,

    size_buffer: wgpu::Buffer,
    size_bind_group: wgpu::BindGroup,

    square_drawer: draw::ShapeDrawer<draw::Square>,

    square_bounces: Vec<(glam::Vec2, glam::Quat, glam::Vec2, glam::Quat)>,

}

impl State {
    pub async fn new(window: &Window) -> Self {

        //--------------------------------------------------

        let size = window.inner_size();

        //--------------------------------------------------

        let instance = wgpu::Instance::new(wgpu::Backends::all());

        let surface = unsafe { instance.create_surface(window)};

        let adapter = instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::default(),
            force_fallback_adapter: false,
            compatible_surface: Some(&surface),
        }).await.unwrap();

        let (device, queue) =  adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: None,
                features: wgpu::Features::empty(),
                limits: wgpu::Limits::default(),
            }, 
            None,
        ).await.unwrap();


        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface.get_preferred_format(&adapter).unwrap(),
            width: size.width,
            height: size.height,
            present_mode: wgpu::PresentMode::Fifo,
        };

        surface.configure(
            &device,
            &config
        );

        //--------------------------------------------------

        let vertex_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("Vertex Buffer"),
                contents: bytemuck::cast_slice(VERTICES),
                usage: wgpu::BufferUsages::VERTEX,
            }
        );

        //--------------------------------------------------

        let time = std::time::Instant::now();
        let time_current = time.elapsed().as_secs_f32();

        let time_bind_group_layout = device.create_bind_group_layout(
            &wgpu::BindGroupLayoutDescriptor {
                label: Some("Time Bind Group Layout"),
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Buffer {
                             ty: wgpu::BufferBindingType::Uniform, 
                             has_dynamic_offset: false, 
                             min_binding_size: None, 
                        },
                        count: None,
                    }
                ],
            }
        );

        let time_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("Time Buffer"),
                contents: bytemuck::cast_slice(&[time_current]),
                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            }
        );

        let time_bind_group = device.create_bind_group(
            &wgpu::BindGroupDescriptor {
                label: Some("Time Bind Group"),
                layout: &time_bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: time_buffer.as_entire_binding(),
                    }
                ],
            }
        );

        //--------------------------------------------------

        let size_uniform: [f32; 2] = size.into();

        let size_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("Size Buffer"),
                contents: bytemuck::cast_slice(&size_uniform),
                usage: wgpu::BufferUsages::UNIFORM,
            }
        );

        let size_bind_group_layout = device.create_bind_group_layout(
            &wgpu::BindGroupLayoutDescriptor {
                label: Some("Size Bind Group Layout"),
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Buffer { 
                            ty: wgpu::BufferBindingType::Uniform, 
                            has_dynamic_offset: false, 
                            min_binding_size: None, 
                        },
                        count: None,
                    }
                ],
            }
        );

        let size_bind_group = device.create_bind_group(
            &wgpu::BindGroupDescriptor {
                label: Some("Size Bind Group"),
                layout: &size_bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: size_buffer.as_entire_binding(),
                    }
                ],
            }
        );

        //--------------------------------------------------

        let render_pipeline_layout = device.create_pipeline_layout(
            &wgpu::PipelineLayoutDescriptor {
                label: Some("Render Pipeline Layout"),
                bind_group_layouts: &[
                    &time_bind_group_layout,
                    &size_bind_group_layout,
                ],
                push_constant_ranges: &[

                ],
            }
        );

        let shader = device.create_shader_module(
            &wgpu::ShaderModuleDescriptor {
                label: Some("Shader Main"),
                source: wgpu::ShaderSource::Wgsl(include_str!("shader.wgsl").into()),
            }
        );

        let render_pipeline = device.create_render_pipeline(
            &wgpu::RenderPipelineDescriptor {
                label: Some("Render Pipeline"),
                layout: Some(&render_pipeline_layout),
                vertex: wgpu::VertexState {
                    module: &shader,
                    entry_point: "vs_main",
                    buffers: &[
                        Vertex::desc(),
                        draw::InstanceRaw::desc(),
                    ],
                },
                fragment: Some(wgpu::FragmentState {
                    module: &shader,
                    entry_point: "fs_main",
                    targets: &[
                        wgpu::ColorTargetState {
                            format: config.format,
                            blend: Some(wgpu::BlendState::REPLACE),
                            write_mask: wgpu::ColorWrites::ALL,
                        }
                    ],
                }),
                primitive: wgpu::PrimitiveState {
                    topology: wgpu::PrimitiveTopology::TriangleList,
                    strip_index_format: None,
                    front_face: wgpu::FrontFace::Ccw,
                    cull_mode: Some(wgpu::Face::Back),
                    unclipped_depth: false,
                    polygon_mode: wgpu::PolygonMode::Fill,
                    conservative: false,
                },
                depth_stencil: None,
                multisample: wgpu::MultisampleState {
                    count: 1,
                    mask: !0,
                    alpha_to_coverage_enabled: false,
                },
                multiview: None,
            }
        );

        //--------------------------------------------------

        let square_drawer = ShapeDrawer::new(&device);

        //--------------------------------------------------

        let mut rng = rand::thread_rng();

        //let angle = glam::Vec2::from_angle(rand::Rng::gen_range(&mut rng, 0_f32..360_f32).to_radians());

        let square_bounces = (0..20).map(|_| {
            (
                glam::Vec2::new(0.0, 0.0),
                glam::Quat::from_rotation_z(0.0),
                glam::Vec2::from_angle(rand::Rng::gen_range(&mut rng, 0_f32..360_f32).to_radians()) *
                    rand::Rng::gen_range(&mut rng, 3..10) as f32 * 0.001,
                glam::Quat::from_rotation_z(rand::Rng::gen_range(&mut rng, 0_f32..1_f32).to_radians()),
            )
                
            
        }).collect::<_>();

        //--------------------------------------------------

        Self {
            surface,
            device,
            queue,
            config,
            size,

            render_pipeline,
            vertex_buffer,

            time,
            time_current,
            time_buffer,
            time_bind_group,

            size_buffer,
            size_bind_group,

            square_drawer,
            square_bounces,
        }

        //--------------------------------------------------

    }

    pub fn resize(&mut self, new_size: winit::dpi::PhysicalSize<u32>) {
        if new_size.width > 0 && new_size.height > 0 {
            self.size = new_size;


            let size_uniform: [f32; 2] = self.size.into();

            self.size_buffer = self.device.create_buffer_init(
                &wgpu::util::BufferInitDescriptor {
                    label: Some("Size Buffer"),
                    contents: bytemuck::cast_slice(&size_uniform),
                    usage: wgpu::BufferUsages::UNIFORM,
                }
            );


            self.config.width = new_size.width;
            self.config.height = new_size.height;
            self.surface.configure(&self.device, &self.config);
        }
    }

    pub fn input(&mut self, _event: &WindowEvent) -> bool {

        return false;
    }

    pub fn update(&mut self) {
        self.time_current = self.time.elapsed().as_secs_f32();
        self.queue.write_buffer(&self.time_buffer, 0, bytemuck::cast_slice(&[self.time_current]));

        let mut rng = rand::thread_rng();

        for mut square in &mut self.square_bounces {
            square.0 += square.2;
            if -1. > square.0.x || square.0.x > 1. { 
                square.2.x = -square.2.x;
                square.3 = square.3.mul_quat(
                    glam::Quat::from_rotation_z(
                        (rand::Rng::gen::<f32>(&mut rng) - 0.5 ).to_radians()
                    )
                );
            }
            if -1. > square.0.y || square.0.y > 1. { 
                square.2.y = -square.2.y; 
                square.3 = square.3.mul_quat(
                    glam::Quat::from_rotation_z(
                        (rand::Rng::gen_range(&mut rng, -1..1) as f32).to_radians()
                    )
                );
            }

            square.1 = square.1.mul_quat(square.3);

            //println!("Drawing cube. pos = {}, dir = {}, rotation = {}, spin = {}", square.0, square.2, square.1, square.3);

            self.square_drawer.draw_instance(
                draw::Instance {
                    translation: square.0.extend(0.),
                    rotation: square.1,
                    scale: glam::Vec3::new(1., 1., 0.) * 2.0,
                }
            );
        }

        self.square_drawer.update_instance_buffer(&self.device, &self.queue);
    }

    pub fn render(&self) -> Result<(), wgpu::SurfaceError> {

        let output = self.surface.get_current_texture()?;
        let view = output.texture.create_view(&wgpu::TextureViewDescriptor::default());
        
        let mut encoder = self.device.create_command_encoder(
            &wgpu::CommandEncoderDescriptor {label: Some("Render Encoder"),}
        );

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Render Pass"),
                color_attachments: &[
                    wgpu::RenderPassColorAttachment {
                        view: &view,
                        resolve_target: None,
                        ops: wgpu::Operations {
                            load: wgpu::LoadOp::Clear(wgpu::Color {
                                r: 0.2,
                                g: 0.2,
                                b: 0.2,
                                a: 1.0,
                            }),
                            store: true,
                        }
                    }
                ],
                depth_stencil_attachment: None,
            });



            render_pass.set_pipeline(&self.render_pipeline);


            render_pass.set_vertex_buffer(
                0, 
                self.square_drawer.get_vertex_buffer().slice(..)
            );

            render_pass.set_vertex_buffer(  //Instance Buffer
                1,
                self.square_drawer.get_instance_buffer().slice(..)
            );

            render_pass.set_index_buffer(
                self.square_drawer.get_index_buffer().slice(..), 
                wgpu::IndexFormat::Uint16
            );

            render_pass.set_bind_group(0, &self.time_bind_group, &[]);
            render_pass.set_bind_group(1, &self.size_bind_group, &[]);

            //println!("Instance count : {}", self.square_drawer.get_instance_count());

            render_pass.draw_indexed(
                0..self.square_drawer.get_index_count(),
                0,
                0..self.square_drawer.get_instance_count(),
            );

        }

        self.queue.submit(std::iter::once(encoder.finish()));
        output.present();

        Ok(())
    }

    pub fn get_size(&self) -> winit::dpi::PhysicalSize<u32> {
        return self.size;
    }
}

//====================================================================