﻿/*
Copyright (c) 2017 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module main;

import std.stdio;
import std.math;
import std.random;
import std.algorithm;

import dagon;

import dmech.world;
import dmech.geometry;
import dmech.rigidbody;
import dmech.bvh;
import dmech.raycast;

import rigidbodycontroller;
import character;
import vehicle;

BVHTree!Triangle meshBVH(Mesh[] meshes)
{
    DynamicArray!Triangle tris;

    foreach(mesh; meshes)
    foreach(tri; mesh)
    {
        Triangle tri2 = tri;
        tri2.v[0] = tri.v[0];
        tri2.v[1] = tri.v[1];
        tri2.v[2] = tri.v[2];
        tri2.normal = tri.normal;
        tri2.barycenter = (tri2.v[0] + tri2.v[1] + tri2.v[2]) / 3;
        tris.append(tri2);
    }

    assert(tris.length);
    BVHTree!Triangle bvh = New!(BVHTree!Triangle)(tris, 4);
    tris.free();
    return bvh;
}

class TestScene: BaseScene3D
{
    FontAsset aFontDroidSans14;

    TextureAsset aTexImrodDiffuse;
    TextureAsset aTexImrodNormal;
    
    TextureAsset aTexStoneDiffuse;
    TextureAsset aTexStoneNormal;
    TextureAsset aTexStoneHeight;
    
    TextureAsset aTexStone2Diffuse;
    TextureAsset aTexStone2Normal;
    TextureAsset aTexStone2Height;
    
    TextureAsset aTexCrateDiffuse;
    
    TextureAsset aTexParticle;
    TextureAsset aTexParticleDust;
    
    TextureAsset aTexCarDiffuse;
    TextureAsset aTexCarNormal;
    
    TextureAsset aTexCarHeadlightsDiffuse;
    TextureAsset aTexCarTyreDiffuse;
    TextureAsset aTexCarTyreNormal;
    
    OBJAsset aCastle;
    OBJAsset aImrod;
    OBJAsset aCrate;
    OBJAsset aSphere;
    
    OBJAsset aCarPaintedParts;
    OBJAsset aCarChromeParts;
    OBJAsset aCarPlasticParts;
    OBJAsset aCarGlassParts;
    OBJAsset aCarLightsFront;
    OBJAsset aCarLightsBack;
    OBJAsset aCarDisk;
    OBJAsset aCarTyre;
    
    IQMAsset iqm;
    
    Entity eMrfixit;
    Actor actor;
    
    PBRClusteredBackend pbrMatBackend;
    ShadelessBackend shadelessMatBackend;
    SkyBackend skyMatBackend;
    float sunPitch = -45.0f;
    float sunTurn = 0.0f;
    
    FirstPersonView fpview;
    CarView carView;
    bool carViewEnabled = false;
    
    Entity eSky;
    
    PhysicsWorld world;
    RigidBody bGround;
    float lightBallRadius = 0.5f;
    Geometry gLightBall;
    CharacterController character;
    VehicleController vehicle;
    
    BVHTree!Triangle bvh;
    bool haveBVH = false;
    
    Entity[4] eWheels;
    ParticleSystem psysLeft;
    ParticleSystem psysRight;
    
    Framebuffer fb;
    Framebuffer fbAA;
    PostFilterFXAA fxaa;
    PostFilterLensDistortion lens;
    
    string helpTextFirstPerson = "Press <LMB> to switch mouse look, WASD to move, spacebar to jump, <RMB> to create a light, arrow keys to rotate the sun";
    string helpTextVehicle = "Press W/S to accelerate forward/backward, A/D to steer, Enter to get out of the car";
    
    TextLine helpText;
    TextLine infoText;
    TextLine messageText;
    
    Entity eMessage;
  
    Color4f[9] lightColors = [
        Color4f(1, 1, 1, 1),
        Color4f(1, 0, 0, 1),
        Color4f(1, 0.5, 0, 1),
        Color4f(1, 1, 0, 1),
        Color4f(0, 1, 0, 1),
        Color4f(0, 1, 0.5, 1),
        Color4f(0, 1, 1, 1),
        Color4f(0, 0.5, 1, 1),
        Color4f(0, 0, 1, 1)
    ];

    bool joystickButtonAPressed;
    bool joystickButtonBPressed;

    this(SceneManager smngr)
    {
        super(smngr);
    }

    override void onAssetsRequest()
    {
        aFontDroidSans14 = addFontAsset("data/font/DroidSans.ttf", 14);
    
        aTexImrodDiffuse = addTextureAsset("data/textures/imrod-diffuse.png");
        aTexImrodNormal = addTextureAsset("data/textures/imrod-normal.png");
        
        aTexStoneDiffuse = addTextureAsset("data/textures/stone-albedo.png");
        aTexStoneNormal = addTextureAsset("data/textures/stone-normal.png");
        aTexStoneHeight = addTextureAsset("data/textures/stone-height.png");
        
        aTexStone2Diffuse = addTextureAsset("data/textures/stone2-albedo.png");
        aTexStone2Normal = addTextureAsset("data/textures/stone2-normal.png");
        aTexStone2Height = addTextureAsset("data/textures/stone2-height.png");
        
        aTexCrateDiffuse = addTextureAsset("data/textures/crate.png");

        aTexParticle = addTextureAsset("data/textures/particle.png");
        aTexParticleDust = addTextureAsset("data/textures/dust.png");
        
        aCastle = New!OBJAsset(assetManager);
        addAsset(aCastle, "data/obj/castle.obj");
        
        aImrod = New!OBJAsset(assetManager);
        addAsset(aImrod, "data/obj/imrod.obj");
        
        aCrate = New!OBJAsset(assetManager);
        addAsset(aCrate, "data/obj/crate.obj");
        
        aSphere = New!OBJAsset(assetManager);
        addAsset(aSphere, "data/obj/sphere.obj");
        
        assetManager.mountDirectory("data/iqm");
        iqm = New!IQMAsset(assetManager);
        addAsset(iqm, "data/iqm/mrfixit.iqm");
        
        aCarPaintedParts = New!OBJAsset(assetManager);
        addAsset(aCarPaintedParts, "data/car/ac-cobra-painted-parts.obj");
        
        aCarChromeParts = New!OBJAsset(assetManager);
        addAsset(aCarChromeParts, "data/car/ac-cobra-chrome-parts.obj");
        
        aCarPlasticParts = New!OBJAsset(assetManager);
        addAsset(aCarPlasticParts, "data/car/ac-cobra-plastic-parts.obj");
        
        aCarGlassParts = New!OBJAsset(assetManager);
        addAsset(aCarGlassParts, "data/car/ac-cobra-glass-parts.obj");
        
        aCarLightsFront = New!OBJAsset(assetManager);
        addAsset(aCarLightsFront, "data/car/ac-cobra-lights-front.obj");
        
        aCarLightsBack = New!OBJAsset(assetManager);
        addAsset(aCarLightsBack, "data/car/ac-cobra-lights-back.obj");
        
        aCarDisk = New!OBJAsset(assetManager);
        addAsset(aCarDisk, "data/car/ac-cobra-disk.obj");
        
        aCarTyre = New!OBJAsset(assetManager);
        addAsset(aCarTyre, "data/car/ac-cobra-tyre.obj");
        
        aTexCarDiffuse = addTextureAsset("data/car/ac-cobra-painted-parts.png");
        aTexCarHeadlightsDiffuse = addTextureAsset("data/car/ac-cobra-lights-front.png");
        aTexCarTyreDiffuse = addTextureAsset("data/car/ac-cobra-wheel.png");
        aTexCarTyreNormal = addTextureAsset("data/car/ac-cobra-wheel-normal.png");
    }

    override void onAllocate()
    {
        super.onAllocate();
        
        // Configure environment
        environment.useSkyColors = true;
        environment.atmosphericFog = true;
        environment.fogStart = 0.0f;
        environment.fogEnd = 300.0f;
        
        // Create camera and view
        auto eCamera = createEntity3D();
        eCamera.position = Vector3f(25.0f, 5.0f, 0.0f);
        fpview = New!FirstPersonView(eventManager, eCamera, assetManager);
        fpview.camera.turn = -90.0f;
        view = fpview;
        
        // Create Framebuffers for post-processing
        fb = New!Framebuffer(eventManager.windowWidth, eventManager.windowHeight, assetManager);
        fbAA = New!Framebuffer(eventManager.windowWidth, eventManager.windowHeight, assetManager);
        fxaa = New!PostFilterFXAA(fb, assetManager);
        lens = New!PostFilterLensDistortion(fbAA, assetManager);

        // Create material backends
        pbrMatBackend = New!PBRClusteredBackend(lightManager, assetManager);
        pbrMatBackend.shadowMap = shadowMap;
        shadelessMatBackend = New!ShadelessBackend(assetManager);
        skyMatBackend = New!SkyBackend(assetManager);
        
        GenericMaterialBackend matBackend = pbrMatBackend;
        
        // Create materials
        auto matDefault = createMaterial(matBackend);
        matDefault.roughness = 0.5f;
        matDefault.metallic = 0.0f;
        matDefault.culling = false;
        
        auto matImrod = createMaterial(matBackend);
        matImrod.diffuse = aTexImrodDiffuse.texture;
        matImrod.normal = aTexImrodNormal.texture;
        matImrod.roughness = 0.5f;
        matImrod.metallic = 0.0f;

        auto mStone = createMaterial(matBackend);
        mStone.diffuse = aTexStoneDiffuse.texture;
        mStone.normal = aTexStoneNormal.texture;
        mStone.height = aTexStoneHeight.texture;
        mStone.roughness = 0.9f;
        mStone.parallax = ParallaxSimple; //also try ParallaxOcclusionMapping
        mStone.metallic = 0.0f;
        
        auto mGround = createMaterial(matBackend);
        mGround.diffuse = aTexStone2Diffuse.texture;
        mGround.normal = aTexStone2Normal.texture;
        mGround.height = aTexStone2Height.texture;
        mGround.roughness = 0.5f;
        mGround.parallax = ParallaxSimple;
        
        auto mCrate = createMaterial(matBackend);
        mCrate.diffuse = aTexCrateDiffuse.texture;
        mCrate.roughness = 0.9f;
        mCrate.metallic = 0.0f;
        
        auto matCar = createMaterial(matBackend);
        matCar.diffuse = aTexCarDiffuse.texture;
        matCar.roughness = 0.0f;
        matCar.metallic = 0.5f;
        matCar.culling = false;
        
        auto matChrome = createMaterial(matBackend);
        matChrome.diffuse = Color4f(0.9f, 1.0f, 1.0f, 1.0f);
        matChrome.roughness = 0.0f;
        matChrome.metallic = 0.98f;
        
        auto matPlastic = createMaterial(matBackend);
        matPlastic.diffuse = Color4f(0.2f, 0.2f, 0.2f, 1.0f);
        matPlastic.roughness = 0.5f;
        matPlastic.metallic = 0.0f;
        
        auto matGlass = createMaterial(matBackend);
        matGlass.diffuse = Color4f(0.0f, 0.0f, 0.0f, 0.3f);
        matGlass.roughness = 0.5f;
        matGlass.metallic = 0.0f;
        matGlass.blending = Transparent;
        
        auto matGlass2 = createMaterial(matBackend);
        matGlass2.diffuse = aTexCarHeadlightsDiffuse.texture;
        matGlass2.roughness = 0.001f;
        matGlass2.metallic = 0.0f;
        matGlass2.blending = Transparent;
        
        auto matGlass3 = createMaterial(matBackend);
        matGlass3.diffuse = Color4f(0.3f, 0.0f, 0.0f, 0.5f);
        matGlass3.roughness = 0.001f;
        matGlass3.metallic = 0.0f;
        matGlass3.blending = Transparent;
        
        auto matWheel = createMaterial(matBackend);
        matWheel.diffuse = aTexCarTyreDiffuse.texture;
        matWheel.normal = aTexCarTyreNormal.texture;
        matWheel.roughness = 0.6f;
        matWheel.metallic = 0.0f;
        
        auto matSky = createMaterial(skyMatBackend);
        matSky.depthWrite = false;
        
        // Create skydome entity
        eSky = createEntity3D();
        eSky.attach = Attach.Camera;
        eSky.castShadow = false;
        eSky.material = matSky;
        eSky.drawable = aSphere.mesh;
        eSky.scaling = Vector3f(100.0f, 100.0f, 100.0f);

        // Create castle entity
        Entity eCastle = createEntity3D();
        eCastle.drawable = aCastle.mesh;
        eCastle.material = mStone;
        
        // Create Imrod entity
        Entity eImrod = createEntity3D();
        eImrod.material = matImrod;
        eImrod.drawable = aImrod.mesh;
        eImrod.position.x = -2.0f;
        eImrod.scaling = Vector3f(0.5, 0.5, 0.5);
        
        // Create Mr Fixit entity (animated model)
        actor = New!Actor(iqm.model, assetManager);
        eMrfixit = createEntity3D();
        eMrfixit.drawable = actor;
        eMrfixit.material = matDefault;
        eMrfixit.position.x = 2.0f;
        eMrfixit.rotation = rotationQuaternion(Axis.y, degtorad(-90.0f));
        eMrfixit.scaling = Vector3f(0.25, 0.25, 0.25);
        eMrfixit.defaultController.swapZY = true;
        
        // Create physics world 
        world = New!PhysicsWorld(assetManager);

        // Create BVH for castle model to handle collisions
        Mesh[] meshes = [aCastle.mesh];
        bvh = meshBVH(meshes);
        haveBVH = true;
        world.bvhRoot = bvh.root;
        
        // Create ground plane
        RigidBody bGround = world.addStaticBody(Vector3f(0.0f, 0.0f, 0.0f));
        auto gGround = New!GeomBox(world, Vector3f(100.0f, 1.0f, 100.0f));
        world.addShapeComponent(bGround, gGround, Vector3f(0.0f, -1.0f, 0.0f), 1.0f);
        auto eGround = createEntity3D();
        eGround.drawable = New!ShapePlane(200, 200, 100, assetManager);
        eGround.material = mGround;

        // Create dmech geometries for dynamic objects
        gLightBall = New!GeomSphere(world, lightBallRadius);
        auto gSphere = New!GeomEllipsoid(world, Vector3f(0.9f, 1.0f, 0.9f));
        
        // Create character controller
        character = New!CharacterController(world, fpview.camera.position, 80.0f, gSphere, assetManager);
        auto gSensor = New!GeomBox(world, Vector3f(0.5f, 0.5f, 0.5f));
        character.createSensor(gSensor, Vector3f(0.0f, -0.75f, 0.0f));

        // Create boxes
        auto gCrate = New!GeomBox(world, Vector3f(1.0f, 1.0f, 1.0f));
        foreach(i; 0..5)
        {
            auto eCrate = createEntity3D();
            eCrate.drawable = aCrate.mesh;
            eCrate.material = mCrate;
            eCrate.position = Vector3f(i * 0.1f, 3.0f + 3.0f * cast(float)i, -5.0f);
            auto bCrate = world.addDynamicBody(Vector3f(0, 0, 0), 0.0f);
            RigidBodyController rbc = New!RigidBodyController(eCrate, bCrate);
            eCrate.controller = rbc;
            world.addShapeComponent(bCrate, gCrate, Vector3f(0.0f, 0.0f, 0.0f), 10.0f);
        }

        // Create car
        Entity eCar = createEntity3D();
        eCar.drawable = aCarPaintedParts.mesh;
        eCar.material = matCar;
        eCar.position = Vector3f(30.0f, 5.0f, 0.0f);
        
        Entity eCarChrome = createEntity3D(eCar);
        eCarChrome.drawable = aCarChromeParts.mesh;
        eCarChrome.material = matChrome;
        
        Entity eCarPlastic = createEntity3D(eCar);
        eCarPlastic.drawable = aCarPlasticParts.mesh;
        eCarPlastic.material = matPlastic;
        
        Entity eCarGlass = createEntity3D(eCar);
        eCarGlass.drawable = aCarGlassParts.mesh;
        eCarGlass.material = matGlass;
        
        Entity eCarLightsFront = createEntity3D(eCar);
        eCarLightsFront.drawable = aCarLightsFront.mesh;
        eCarLightsFront.material = matGlass2;
        
        Entity eCarLightsBack = createEntity3D(eCar);
        eCarLightsBack.drawable = aCarLightsBack.mesh;
        eCarLightsBack.material = matGlass3;

        auto gBox = New!GeomBox(world, Vector3f(1.3f, 0.6f, 2.8f));
        auto b = world.addDynamicBody(Vector3f(0, 0, 0), 0.0f);
        b.damping = 0.8f;
        vehicle = New!VehicleController(eCar, b, world);
        eCar.controller = vehicle;
        world.addShapeComponent(b, gBox, Vector3f(0.0f, 0.8f, 0.0f), 1200.0f);
        b.centerOfMass.y = 0.1f; // Artifically lowered center of mass
        b.centerOfMass.z = 0.25f;
        
        foreach(i, ref w; eWheels)
        {
            w = createEntity3D(eCar);
            w.drawable = aCarDisk.mesh;
            w.material = matChrome;
            
            auto t = createEntity3D(w);
            t.drawable = aCarTyre.mesh;
            t.material = matWheel;
        }
        
        carView = New!CarView(eventManager, vehicle, assetManager);
        carViewEnabled = false;
        
        auto mParticlesDust = createMaterial(shadelessMatBackend); // TODO: a specialized particle material backend
        mParticlesDust.diffuse = aTexParticleDust.texture;
        mParticlesDust.blending = Transparent;
        mParticlesDust.depthWrite = false;
        
        auto eParticlesRights = createEntity3D(eCar);
        psysRight = New!ParticleSystem(eParticlesRights, 20);
        eParticlesRights.position = Vector3f(-1.2f, 0, -2.8f);
        psysRight.minLifetime = 0.1f;
        psysRight.maxLifetime = 1.5f;
        psysRight.minSize = 0.5f;
        psysRight.maxSize = 1.0f;
        psysRight.minInitialSpeed = 0.2f;
        psysRight.maxInitialSpeed = 0.2f;
        psysRight.scaleStep = Vector2f(1, 1);
        psysRight.material = mParticlesDust;

        auto eParticlesLeft = createEntity3D(eCar);
        psysLeft = New!ParticleSystem(eParticlesLeft, 20);
        eParticlesLeft.position = Vector3f(1.2f, 0, -2.8f);
        psysLeft.minLifetime = 0.1f;
        psysLeft.maxLifetime = 1.5f;
        psysLeft.minSize = 0.5f;
        psysLeft.maxSize = 1.0f;
        psysLeft.minInitialSpeed = 0.2f;
        psysLeft.maxInitialSpeed = 0.2f;
        psysLeft.scaleStep = Vector2f(1, 1);
        psysLeft.material = mParticlesDust;

        // Create HUD text
        helpText = New!TextLine(aFontDroidSans14.font, helpTextFirstPerson, assetManager);
        helpText.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        
        auto eText = createEntity2D();
        eText.drawable = helpText;
        eText.position = Vector3f(16.0f, 30.0f, 0.0f);
        
        infoText = New!TextLine(aFontDroidSans14.font, "0", assetManager);
        infoText.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        
        auto eText2 = createEntity2D();
        eText2.drawable = infoText;
        eText2.position = Vector3f(16.0f, 60.0f, 0.0f);
        
        messageText = New!TextLine(aFontDroidSans14.font, 
            "Press <Enter> to get in the car", 
            assetManager);
        messageText.color = Color4f(1.0f, 1.0f, 1.0f, 0.0f);
        
        auto eMessage = createEntity2D();
        eMessage.drawable = messageText;
        eMessage.position = Vector3f(eventManager.windowWidth * 0.5f - messageText.width * 0.5f, eventManager.windowHeight * 0.5f, 0.0f);
    }
    
    override void onStart()
    {
        super.onStart();
        actor.play();
    }
    
    override void onJoystickButtonDown(int button)
    {    
        if (button == SDL_CONTROLLER_BUTTON_A)
            joystickButtonAPressed = true;
        else if (button == SDL_CONTROLLER_BUTTON_B)
            joystickButtonBPressed = true;
    }
    
    override void onJoystickButtonUp(int button)
    {    
        if (button == SDL_CONTROLLER_BUTTON_A)
            joystickButtonAPressed = false;
        else if (button == SDL_CONTROLLER_BUTTON_B)
            joystickButtonBPressed = false;
    }
    
    override void onKeyDown(int key)
    {
        if (key == KEY_ESCAPE)
            exitApplication();
        else if (key == KEY_RETURN)
        {
            if (carViewEnabled)
            {
                view = fpview;
                carViewEnabled = false;
                character.rbody.active = true;
                character.rbody.position = vehicle.rbody.position + vehicle.rbody.orientation.rotate(Vector3f(1.0f, 0.0f, 0.0f).normalized) * 4.0f + Vector3f(0, 3, 0);
                helpText.text = helpTextFirstPerson;
            }
            else if (distance(fpview.cameraPosition, vehicle.rbody.position) <= 4.0f)
            {
                view = carView;
                carViewEnabled = true;
                character.rbody.active = false;
                helpText.text = helpTextVehicle;
            }
        }
    }
    
    override void onMouseButtonDown(int button)
    {
        // Toggle mouse look / cursor lock
        if (button == MB_LEFT)
        {
            if (!carViewEnabled)
            {
                if (fpview.active)
                    fpview.active = false;
                else
                    fpview.active = true;
            }
            else
            {
                if (carView.active)
                    carView.active = false;
                else
                    carView.active = true;
            }
        }
        
        // Create a light ball
        if (button == MB_RIGHT && !carViewEnabled)
        {
            Vector3f pos = fpview.camera.position + fpview.camera.characterMatrix.forward * -2.0f + Vector3f(0, 1, 0);
            Color4f color = lightColors[uniform(0, 9)];
            createLightBall(pos, color, 2.0f, lightBallRadius, 8.0f);
        }
    }
    
    Entity createLightBall(Vector3f pos, Color4f color, float energy, float areaRadius, float volumeRadius)
    {
        auto light = createLight(pos, color, energy, volumeRadius, areaRadius);
            
        if (light)
        {
            auto mLightBall = createMaterial(shadelessMatBackend);
            mLightBall.diffuse = color;
                
            auto eLightBall = createEntity3D();
            eLightBall.drawable = aSphere.mesh;
            eLightBall.scaling = Vector3f(-areaRadius, -areaRadius, -areaRadius);
            eLightBall.castShadow = false;
            eLightBall.material = mLightBall;
            eLightBall.position = pos;
            auto bLightBall = world.addDynamicBody(Vector3f(0, 0, 0), 0.0f);
            RigidBodyController rbc = New!RigidBodyController(eLightBall, bLightBall);
            eLightBall.controller = rbc;
            world.addShapeComponent(bLightBall, gLightBall, Vector3f(0.0f, 0.0f, 0.0f), 10.0f);
                
            LightBehaviour lc = New!LightBehaviour(eLightBall, light);
            
            return eLightBall;
        }
        
        return null;
    }
    
    // Character control
    void updateCharacter(double dt)
    {
        character.rotation.y = fpview.camera.turn;
        Vector3f forward = fpview.camera.characterMatrix.forward;
        Vector3f right = fpview.camera.characterMatrix.right; 
        float speed = 8.0f;
        Vector3f dir = Vector3f(0, 0, 0);
        if (eventManager.keyPressed[KEY_W]) dir += -forward;
        if (eventManager.keyPressed[KEY_S]) dir += forward;
        if (eventManager.keyPressed[KEY_A]) dir += -right;
        if (eventManager.keyPressed[KEY_D]) dir += right;
        character.move(dir.normalized, speed);
        if (eventManager.keyPressed[KEY_SPACE]) character.jump(2.0f);
        character.update();
    }

    void updateVehicle(double dt)
    {
        float accelerate = 100.0f;
    
        if (eventManager.keyPressed[KEY_Z])
            vehicle.accelerateForward(accelerate);
        else if (eventManager.keyPressed[KEY_X])
            vehicle.accelerateBackward(accelerate);
    
        if (carViewEnabled)
        {
            if (eventManager.keyPressed[KEY_W] || joystickButtonAPressed)
                vehicle.accelerateForward(accelerate);
            else if (eventManager.keyPressed[KEY_S] || joystickButtonBPressed)
                vehicle.accelerateBackward(accelerate);
            else
                vehicle.brake = false;
                
            float jAxis = eventManager.joystickAxis(SDL_CONTROLLER_AXIS_LEFTX);
            
            float steering = min(45.0f * abs(1.0f / max(vehicle.speed, 0.01f)), 5.0f);

            if (eventManager.keyPressed[KEY_A])
                vehicle.steer(-steering);
            else if (eventManager.keyPressed[KEY_D])
                vehicle.steer(steering);
            else if (jAxis < -0.02f || jAxis > 0.02f)
            {
                vehicle.steer(jAxis * steering);
            }
            else
                vehicle.resetSteering();
        }
        
        if (vehicle.wheels[2].isDrifting) psysLeft.emitting = true;
        else psysLeft.emitting = false;
        if (vehicle.wheels[3].isDrifting) psysRight.emitting = true;
        else psysRight.emitting = false;
        
        vehicle.fixedStepUpdate(dt);
        
        foreach(i, ref w; eWheels)
        {
            auto vWheel = vehicle.wheels[i];
            w.position = vWheel.position;
            
            if (vehicle.wheels[i].dirCoef > 0.0f)
            {
                w.rotation = rotationQuaternion(Axis.y, degtorad(-vWheel.steeringAngle)) * 
                             rotationQuaternion(Axis.x, degtorad(vWheel.roll));
            }
            else
            {
                w.rotation = rotationQuaternion(Axis.y, degtorad(-vWheel.steeringAngle + 180.0f)) * 
                             rotationQuaternion(Axis.x, degtorad(-vWheel.roll));
            }
        }
    }
    
    override void onLogicsUpdate(double dt)
    {
        // Update our character, vehicle and physics
        if (!carViewEnabled)
            updateCharacter(dt);
        updateVehicle(dt);
        world.update(dt);
        
        // Place camera to character controller position
        // TODO: maybe make character controller an Entity, so that
        // this could be done automatically with parenting mechanism?
        fpview.camera.position = character.rbody.position;
        
        // Sun control
        if (eventManager.keyPressed[KEY_DOWN]) sunPitch += 30.0f * dt;
        if (eventManager.keyPressed[KEY_UP]) sunPitch -= 30.0f * dt;
        if (eventManager.keyPressed[KEY_LEFT]) sunTurn += 30.0f * dt;
        if (eventManager.keyPressed[KEY_RIGHT]) sunTurn -= 30.0f * dt;
        environment.sunRotation = 
            rotationQuaternion(Axis.y, degtorad(sunTurn)) * 
            rotationQuaternion(Axis.x, degtorad(sunPitch));

        // Update infoText with some debug info
        float speed = vehicle.speed * 3.6f;
        uint n = sprintf(lightsText.ptr, 
            "FPS: %u | visible lights: %u | total lights: %u | max visible lights: %u | speed: %f km/h", 
            eventManager.fps, 
            lightManager.currentlyVisibleLights, 
            lightManager.lightSources.length, 
            lightManager.maxNumLights,
            speed);
        string s = cast(string)lightsText[0..n];
        infoText.setText(s);
        
        if (!carViewEnabled && distance(fpview.cameraPosition, vehicle.rbody.position) <= 4.0f)
        {
            if (messageText.color.a < 1.0f)
                messageText.color.a += 4.0f * dt;
        }
        else
        {
            if (messageText.color.a > 0.0f)
                messageText.color.a -= 4.0f * dt;
        }
    }
    
    char[100] lightsText;
    
    override void onRender()
    {
        // Render shadow map
        renderShadows(&rc3d);
        
        // Render 3D objects to fb for FXAA
        fb.bind();
        prepareViewport();        
        renderEntities3D(&rc3d);
        fb.unbind();
        
        // Render fxaa quad to fbAA for lens distortion
        fbAA.bind();
        prepareViewport();
        fxaa.render(&rc2d);
        fbAA.unbind();
        
        // Render lens distortion quad and 2D objects to main framebuffer
        prepareViewport();
        lens.render(&rc2d);
        renderEntities2D(&rc2d);
    }
    
    override void onRelease()
    {
        super.onRelease();
        
        // If we have created BVH, we should release it
        if (haveBVH)
        {
            bvh.free();
            haveBVH = false;
        }
    }
}

class MyApplication: SceneApplication
{
    this(string[] args)
    {
        super(1280, 720, false, "Dagon demo", args);

        TestScene test = New!TestScene(sceneManager);
        sceneManager.addScene(test, "TestScene");

        sceneManager.goToScene("TestScene");
    }
}

void main(string[] args)
{
    writeln("Allocated memory at start: ", allocatedMemory);
    MyApplication app = New!MyApplication(args);
    app.run();
    Delete(app);
    writeln("Allocated memory at end: ", allocatedMemory);
}
