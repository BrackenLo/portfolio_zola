//====================================================================

use wgpu::util::DeviceExt;

use crate::model;

//====================================================================

pub trait Shape {
    fn new() -> Self;
    fn get_vertices<'a>() -> &'a [model::Vertex];
    fn get_indices<'a>() -> &'a [u16];
}

//--------------------------------------------------

pub trait HasInstanceBuffer<'a> {
    fn get_vertex_buffer(&self) -> &wgpu::Buffer;
    fn get_index_buffer(&self) -> &wgpu::Buffer;
    fn get_instance_buffer(&self) -> &wgpu::Buffer;

    fn get_instance_count(&self) -> u32;
    fn get_index_count(&self) -> u32;
}

//--------------------------------------------------

pub struct ShapeDrawer<T: Shape> {
    _shape: T,

    vertex_buffer: wgpu::Buffer,

    index_buffer: wgpu::Buffer,
    indicies: u32,

    instance_buffer: wgpu::Buffer,
    instances: Vec<Instance>,

    instance_count: u32,

}
impl<T: Shape> ShapeDrawer<T> {

    pub fn new(device: &wgpu::Device) -> Self {

        let vertex_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("ShapeDrawer Vertex"),
                contents: bytemuck::cast_slice(T::get_vertices()),
                usage: wgpu::BufferUsages::VERTEX,
            }
        );

        let index_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("ShapeDrawer Index"),
                contents: bytemuck::cast_slice(T::get_indices()),
                usage: wgpu::BufferUsages::INDEX,
            }
        );

        let instances: Vec<InstanceRaw> = vec![
            Instance { 
                translation: glam::Vec3::ONE, 
                rotation: glam::Quat::from_rotation_z(0.), 
                scale: glam::Vec3::ONE, 
            }.to_raw()
        ];

        let instance_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("ShapeDrawer Instance"),
                contents: bytemuck::cast_slice(&instances),
                usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            }
        );


        return Self {
            _shape: T::new(),
            
            vertex_buffer,

            index_buffer,
            indicies: T::get_indices().len() as u32,

            instance_buffer,
            instances: Vec::new(),

            instance_count: 1,
        }

    }

    pub fn draw_instance(&mut self, instance: Instance,) {
        self.instances.push(instance);
    }

    pub fn update_instance_buffer(&mut self, device: &wgpu::Device, queue: &wgpu::Queue) {

        let instance_data = self.instances.iter().map(Instance::to_raw).collect::<Vec<_>>();
        self.instance_buffer = device.create_buffer_init(
            &wgpu::util::BufferInitDescriptor {
                label: Some("Instance Buffer"),
                contents: bytemuck::cast_slice(&instance_data),
                usage: wgpu::BufferUsages::VERTEX,
            }
        );
        //queue.write_buffer(&self.instance_buffer, 0, &[]);
        
        //println!("help");
        // queue.write_buffer(
        //     &self.instance_buffer, 
        //     0, 
        //     bytemuck::cast_slice(&instance_data),
        // );

        //println!("hhelp2");

        self.instance_count = instance_data.len() as u32;
        self.instances.clear();
    }
}




impl<'a, T: Shape> HasInstanceBuffer<'a> for ShapeDrawer<T> {
    fn get_vertex_buffer(&self) -> &wgpu::Buffer {
        return &self.vertex_buffer;
    }

    fn get_index_buffer(&self) -> &wgpu::Buffer {
        return &self.index_buffer;
    }

    fn get_instance_buffer(&self) -> &wgpu::Buffer {
        return &self.instance_buffer;
    }

    fn get_instance_count(&self) -> u32 {
        return self.instance_count;
    }

    fn get_index_count(&self) -> u32 {
        return self.indicies;
    }
}

//--------------------------------------------------

const SQUARE_VERTICES: &[model::Vertex] = &[
    model::Vertex { position: [-0.1,  0.1, 1.0] },
    model::Vertex { position: [-0.1, -0.1, 1.0] },
    model::Vertex { position: [ 0.1, -0.1, 1.0] },
    model::Vertex { position: [ 0.1,  0.1, 1.0] },
];
 

pub struct Square {}

impl Shape for Square {
    fn new() -> Self {
        return Square{};
    }

    
    fn get_vertices<'a>() -> &'a [model::Vertex] {
        
        return SQUARE_VERTICES;

    }

    fn get_indices<'a>() -> &'a [u16] {
        
        return &[
            0, 1, 2,
            0, 2, 3,
        ];
    }
}

//====================================================================

pub struct Instance {
    pub translation: glam::Vec3,
    pub rotation: glam::Quat,
    pub scale: glam::Vec3,
}

impl Instance {
    fn to_raw(&self) -> InstanceRaw {

        InstanceRaw {
            model: glam::Mat4::from_scale_rotation_translation(
                self.scale, 
                self.rotation, 
                self.translation,
            ).to_cols_array_2d(),
            //model: glam::Mat4::from_rotation_translation(self.rotation, self.translation).to_cols_array_2d(),
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct InstanceRaw {
    model: [[f32; 4]; 4],
}
impl InstanceRaw {
    pub fn desc<'a>() -> wgpu::VertexBufferLayout<'a> {
        use std::mem;
        wgpu::VertexBufferLayout {
            array_stride: mem::size_of::<InstanceRaw>() as wgpu::BufferAddress,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &[
                wgpu::VertexAttribute {
                    offset: 0,
                    // While our vertex shader only uses locations 0, and 1 now, in later tutorials we'll
                    // be using 2, 3, and 4, for Vertex. We'll start at slot 5 not conflict with them later
                    shader_location: 5,
                    format: wgpu::VertexFormat::Float32x4,
                },
                wgpu::VertexAttribute {
                    offset: mem::size_of::<[f32; 4]>() as wgpu::BufferAddress,
                    shader_location: 6,
                    format: wgpu::VertexFormat::Float32x4,
                },
                wgpu::VertexAttribute {
                    offset: mem::size_of::<[f32; 8]>() as wgpu::BufferAddress,
                    shader_location: 7,
                    format: wgpu::VertexFormat::Float32x4,
                },
                wgpu::VertexAttribute {
                    offset: mem::size_of::<[f32; 12]>() as wgpu::BufferAddress,
                    shader_location: 8,
                    format: wgpu::VertexFormat::Float32x4,
                },
            ],
        }
    }
}

//====================================================================