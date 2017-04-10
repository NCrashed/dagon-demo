module physicstest;

import std.stdio;

import dagon;

import dmech.world;
import dmech.geometry;
import dmech.rigidbody;

import character;

class RigidBodyController: EntityController
{
    RigidBody rbody;

    this(Entity e, RigidBody b)
    {
        super(e);
        rbody = b;
        b.position = e.position;
        b.orientation = e.rotation;
    }

    override void update(double dt)
    {
        entity.position = rbody.position;
        entity.rotation = rbody.orientation; 
        entity.transformation = rbody.transformation;
        entity.invTransformation = entity.transformation.inverse;
    }
}

class PhysicsScene: Scene
{
    LightManager lightManager;

    RenderingContext rc3d; 
    RenderingContext rc2d;
 
    FirstPersonView fpview;

    PhysicsWorld world;
    double physicsTimer;
    enum fixedTimeStep = 1.0 / 60.0;

    RigidBody bGround;
    Geometry gGround;

    DynamicArray!Entity entities3D;
    DynamicArray!Entity entities2D;

    Geometry gBox;

    GeomEllipsoid gSphere;
    GeomBox gSensor;
    CharacterController character;

    TextureAsset aloadingTex;
    TextureAsset atex;

    FontAsset afont;

    this(SceneManager smngr)
    {
        super(smngr);
        assetManager.liveUpdate = false;
    }

    override void onAssetsRequest()
    {
        aloadingTex = addTextureAsset("data/ui/loading.png", true);
        atex = addTextureAsset("data/textures/crate.jpg");
        afont = addFontAsset("data/font/DroidSans.ttf", 18);
    }

    override void onLoading(float percentage)
    {
        glDisable(GL_DEPTH_TEST);

        glViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glMatrixMode(GL_PROJECTION);
        auto projectionMatrix2D = orthoMatrix(
            0.0f, eventManager.windowWidth, 0.0f, eventManager.windowHeight, 0.0f, 100.0f);
        glLoadMatrixf(projectionMatrix2D.arrayof.ptr);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        float imgX, imgY, imgWidth, imgHeight;
        if (aloadingTex.image.width > aloadingTex.image.height)
        {
            float imgAspect = cast(float)(aloadingTex.image.height) / cast(float)(aloadingTex.image.width);
            imgHeight = eventManager.windowWidth * imgAspect;
            imgWidth = eventManager.windowWidth;
        }
        else
        {
            float imgAspect = cast(float)(aloadingTex.image.width) / cast(float)(aloadingTex.image.height);
            imgWidth = eventManager.windowHeight * imgAspect;
            imgHeight = eventManager.windowHeight;
        }
        imgX = (eventManager.windowWidth - imgWidth) * 0.5f;
        imgY = (eventManager.windowHeight - imgHeight) * 0.5f;

        glColor4f(1, 1, 1, 1);
        aloadingTex.texture.bind();
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(imgX, imgY + imgHeight);
        glTexCoord2f(0, 1); glVertex2f(imgX, imgY);
        glTexCoord2f(1, 1); glVertex2f(imgX + imgWidth, imgY);
        glTexCoord2f(1, 0); glVertex2f(imgX + imgWidth, imgY + imgHeight);
        glEnd();
        aloadingTex.texture.unbind();

        float margin = 0.0f;
        float w = percentage * eventManager.windowWidth;
        glBegin(GL_QUADS);
        glVertex2f(margin, imgY + 8);
        glVertex2f(margin, imgY + margin);
        glVertex2f(w - margin, imgY + margin);
        glVertex2f(w - margin, imgY + 8);
        glEnd();
    }

    Entity createEntity2D()
    {
        Entity e = New!Entity(eventManager, this);
        entities2D.append(e);
        return e;
    }
    
    Entity createEntity3D()
    {
        Entity e = New!Entity(eventManager, this);
        auto lr = New!LightReceiver(e, lightManager);
        entities3D.append(e);
        return e;
    }

    override void onAllocate()
    {
        lightManager = New!LightManager(this);
        lightManager.addPointLight(Vector3f(3, 3, 0), Color4f(1.0, 0.0, 0.0, 1.0));
        lightManager.addPointLight(Vector3f(-3, 3, 0), Color4f(0.0, 1.0, 0.0, 1.0));
        lightManager.addPointLight(Vector3f(0, 3, -3), Color4f(0.0, 0.0, 1.0, 1.0));
        lightManager.addPointLight(Vector3f(-3, 3, -3), Color4f(1.0, 0.0, 1.0, 1.0));

        world = New!PhysicsWorld();
        
        RigidBody bGround = world.addStaticBody(Vector3f(0.0f, -1.0f, 0.0f));
        gGround = New!GeomBox(Vector3f(40.0f, 1.0f, 40.0f));
        world.addShapeComponent(bGround, gGround, Vector3f(0.0f, 0.0f, 0.0f), 1.0f);

        ShapeBox shapeBox = New!ShapeBox(1, 1, 1, this);
        gBox = New!GeomBox(Vector3f(1.0f, 1.0f, 1.0f));

        //auto env = New!Environment(this);

        auto mat = New!GenericMaterial(this);
        mat.diffuse = atex.texture;
        mat.roughness = 0.2f;

        foreach(i; 0..20)
        {
            auto boxE = createEntity3D();
            boxE.drawable = shapeBox;
            boxE.material = mat;
            boxE.position = Vector3f(i * 0.1f, 3.0f + 3.0f * cast(float)i, 0);
            auto bBox = world.addDynamicBody(Vector3f(0, 0, 0), 0.0f);
            RigidBodyController rbc = New!RigidBodyController(boxE, bBox);
            boxE.controller = rbc;
            world.addShapeComponent(bBox, gBox, Vector3f(0.0f, 0.0f, 0.0f), 10.0f);
        }

        fpview = New!FirstPersonView(eventManager, Vector3f(0.0f, 1.8f, 8.0f), this);
        gSphere = New!GeomEllipsoid(Vector3f(0.9f, 1.0f, 0.9f));
        gSensor = New!GeomBox(Vector3f(0.5f, 0.5f, 0.5f));
        character = New!CharacterController(world, fpview.camera.position, 80.0f, gSphere, this);
        character.createSensor(gSensor, Vector3f(0.0f, -0.75f, 0.0f));

        auto text = New!TextLine(afont.font, "Hello! Привет!", this);
        text.color = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
        auto textE = createEntity2D();
        textE.drawable = text;
        textE.position = Vector3f(16.0f, 16.0f, 0.0f);

        //released = false;
    }

    //bool released = true;
    
    override void onRelease()
    {
        //if (!released)
        {
            Delete(world);
            Delete(gGround);
            Delete(gBox);
            Delete(gSphere);
            Delete(gSensor);
            entities3D.free();
            entities2D.free();
            //released = true;
        }
    }

    override void onStart()
    {
        writeln("Allocated memory after scene switch: ", allocatedMemory);

        rc3d.init(eventManager);
        rc3d.projectionMatrix = perspectiveMatrix(60.0f, eventManager.aspectRatio, 0.1f, 100.0f);

        rc2d.init(eventManager);
        rc2d.projectionMatrix = orthoMatrix(0.0f, eventManager.windowWidth, 0.0f, eventManager.windowHeight, 0.0f, 100.0f);
        
        physicsTimer = 0.0;

        eventManager.showCursor(false);
        eventManager.setMouseToCenter();
    }

    override void onEnd()
    {
        eventManager.showCursor(true);
    }

    override void onKeyDown(int key)
    {
        if (key == KEY_ESCAPE)
            sceneManager.loadAndSwitchToScene("Menu");
    }

    void updateCharacter(double dt)
    {
        character.rotation.y = fpview.camera.turn;
        Vector3f forward = fpview.camera.characterMatrix.forward;
        Vector3f right = fpview.camera.characterMatrix.right;
        float speed = 8.0f;
        if (eventManager.keyPressed[KEY_W]) character.move(forward, -speed);
        if (eventManager.keyPressed[KEY_S]) character.move(forward, speed);
        if (eventManager.keyPressed[KEY_A]) character.move(right, -speed);
        if (eventManager.keyPressed[KEY_D]) character.move(right, speed);
        if (eventManager.keyPressed[KEY_SPACE]) character.jump(2.0f);
        character.update();
    }

    void doLogics()
    {
    }

    override void onUpdate(double dt)
    {
        physicsTimer += dt;
        if (physicsTimer >= fixedTimeStep)
        {
            doLogics();
            updateCharacter(fixedTimeStep);

            physicsTimer -= fixedTimeStep;
            world.update(fixedTimeStep);

            fpview.camera.position = character.rbody.position;
            fpview.update(fixedTimeStep);
        }

        foreach(e; entities3D)
            e.update(dt);

        foreach(e; entities2D)
            e.update(dt);

        fpview.prepareRC(&rc3d);
    }

    override void onRender()
    {     
        glEnable(GL_DEPTH_TEST);

        glViewport(0, 0, eventManager.windowWidth, eventManager.windowHeight);
        glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        rc3d.apply();

        foreach(e; entities3D)
            e.render(&rc3d);

        glDisable(GL_DEPTH_TEST); 

        rc2d.apply();

        foreach(e; entities2D)
            e.render(&rc2d);
    } 
}

