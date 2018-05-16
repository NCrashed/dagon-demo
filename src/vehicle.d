﻿/*
Copyright (c) 2017-2018 Timur Gafarov

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

module vehicle;

import std.math;
import std.algorithm;

import dagon;

import dmech.world;
import dmech.rigidbody;
import dmech.geometry;
import dmech.shape;
import dmech.contact;
import dmech.raycast;

class Wheel: Owner
{
    Vector3f suspPosition;
    Vector3f forcePosition;
    Vector3f position;
    float radius;
    float suspMaxLength;
    float suspStiffness; 
    float suspDamping;
    float suspCompression;
    float suspLength;
    float suspLengthPrev;
    float steeringAngle;
    float torque;
    float roll;
    float dirCoef;
    bool powered;
    bool steered;
    float maxSteeringAngle;
    float rollSpeed;
    bool front;
    bool isDrifting;
    bool brake;
    bool handbrake;

    Matrix4x4f transformation;

    this(Vector3f pos, bool powered, bool steered, bool front, Owner o)
    {
        super(o);
        suspPosition = pos;
        forcePosition = Vector3f(0.0f, 0.0f, 0.0f);
        radius = 0.55f;
        suspStiffness = 15000.0f;
        suspDamping = 2000.0f;
        suspCompression = 0.0f;
        suspLength = 0.0f;
        suspLengthPrev = 0.0f;
        suspMaxLength = 0.7f;
        steeringAngle = 0.0f;
        torque = 0.0f;
        position = suspPosition - Vector3f(0.0f, suspMaxLength, 0.0f);
        transformation = Matrix4x4f.identity;
        roll = 0.0f;
        dirCoef = 1.0f;
        this.powered = powered;
        this.steered = steered;
        maxSteeringAngle = 45.0f;
        rollSpeed = 0.0f;
        this.front = front;
        isDrifting = false;
        brake = false;
        handbrake = false;
    }
}

class VehicleController: EntityController
{
    PhysicsWorld world;
    RigidBody rbody;
    Wheel[4] wheels; // TODO: use dynamic array and let the user create wheels
    float torqueAcc;
    bool brake = false;
    float maxForwardTorque = 20000.0f;
    float maxBackwardTorque = 10000.0f;
    float speed = 0.0f;

    this(Entity e, RigidBody b, PhysicsWorld w)
    {
        super(e);

        world = w;

        rbody = b;
        b.position = e.position;
        b.orientation = e.rotation;

        wheels[0] = New!Wheel(Vector3f(-1.25f, 1,  2.0f), false, true, true, this);
        wheels[0].dirCoef = -1.0f;
        wheels[1] = New!Wheel(Vector3f( 1.25f, 1,  2.0f), false, true, true, this);
        wheels[2] = New!Wheel(Vector3f(-1.25f, 1, -1.8f), true, false, false, this);
        wheels[2].dirCoef = -1.0f;
        wheels[3] = New!Wheel(Vector3f( 1.25f, 1, -1.8f), true, false, false, this);

        torqueAcc = 0.0f;
    }

    void accelerateForward(float t)
    {
        if (torqueAcc < 0.0f)
            torqueAcc = 0.0f;
        else
            torqueAcc += t;

        if (torqueAcc > maxForwardTorque)
            torqueAcc = maxForwardTorque;

        uint numPoweredWheels = 0;
        foreach(i, w; wheels)
        if (w.powered)
            numPoweredWheels++;
 
        foreach(i, w; wheels)
        if (w.powered)
        {
            w.torque = torqueAcc / cast(float)numPoweredWheels;
        }
        else
        {
            if (isMovingBackward)
                w.brake = true;
            else
                w.brake = false;
        }
    }

    void accelerateBackward(float t)
    {
        if (torqueAcc > 0.0f)
            torqueAcc = 0.0f;
        else
            torqueAcc -= t;

        if (torqueAcc < -maxBackwardTorque)
            torqueAcc = -maxBackwardTorque;

        uint numPoweredWheels = 0;
        foreach(i, w; wheels)
        if (w.powered)
            numPoweredWheels++;
            
        foreach(i, w; wheels)
        if (w.powered)
        {
            w.torque = torqueAcc / cast(float)numPoweredWheels;
        }
        else
        {
            if (isMovingBackward)
                w.brake = false;
            else
                w.brake = true;
        }
    }

    void steer(float angle)
    {
        foreach(i, w; wheels)
        if (w.steered)
        {
            if (w.front)
            {
                w.steeringAngle += angle;
            }
            
            if (w.steeringAngle > w.maxSteeringAngle + w.dirCoef * 4.0f)
                w.steeringAngle = w.maxSteeringAngle + w.dirCoef * 4.0f;
            else if (w.steeringAngle < -w.maxSteeringAngle - w.dirCoef * 4.0f)
                w.steeringAngle = -w.maxSteeringAngle - w.dirCoef * 4.0f;
        }
    }
    
    void setSteering(float angle)
    {
        foreach(i, w; wheels)
        if (w.steered)
        {
            if (w.front)
            {
                w.steeringAngle = angle;
            }
            
            if (w.steeringAngle > w.maxSteeringAngle + w.dirCoef * 4.0f)
                w.steeringAngle = w.maxSteeringAngle + w.dirCoef * 4.0f;
            else if (w.steeringAngle < -w.maxSteeringAngle - w.dirCoef * 4.0f)
                w.steeringAngle = -w.maxSteeringAngle - w.dirCoef * 4.0f;
        }
    }

    void resetSteering()
    {
        foreach(i, w; wheels)
        if (w.steered)
        {
            if (w.steeringAngle > 0.0f)
                w.steeringAngle -= 2.0f;
            if (w.steeringAngle < 0.0f)
                w.steeringAngle += 2.0f;
        }
    }
    
    void handbrake(bool value)
    {
        foreach(i, w; wheels)
            w.handbrake = value;
    }

    bool downRaycast(Vector3f pos, Vector3f down, out float height, out Vector3f n)
    {
        CastResult castResult;
        if (world.raycast(pos, down, 10, castResult, true, true))
        {
            height = castResult.point.y;
            n = castResult.normal;
            return true;
        }
        else
        {
            height = 0;
            n = Vector3f(0.0f, 1.0f, 0.0f);
            return false;
        }
    }

    void updateWheel(Wheel w, double dt)
    {
        w.transformation = rbody.transformation * 
            translationMatrix(w.position) * rotationMatrix(Axis.y, degtorad(w.steeringAngle));

        Vector3f wheelPosW = rbody.position + rbody.orientation.rotate(w.suspPosition);
        float groundHeight = 0.0f;
        Vector3f groundNormal = Vector3f(0, 1, 0);
        Vector3f down = -w.transformation.up;
        
        rbody.raycastable = false;
        bool isec = downRaycast(wheelPosW, down, groundHeight, groundNormal);
        rbody.raycastable = true;
        
        w.forcePosition = Vector3f(wheelPosW.x, groundHeight, wheelPosW.z);

        float suspToGround = wheelPosW.y - groundHeight;

        bool inAir;

        float invSteepness = clamp(dot(groundNormal, Vector3f(0, 1, 0)), 0.0f, 1.0f);
        
        w.isDrifting = false;
        
        if (suspToGround > (w.suspMaxLength + w.radius)) // wheel is in air
        {
            w.suspCompression = 0.0f;
            w.suspLengthPrev = w.suspMaxLength;
            w.suspLength = w.suspMaxLength;
            w.position = w.suspPosition + Vector3f(0.0f, -w.suspMaxLength, 0.0f);

            inAir = isec;
        }
        else // suspension is compressed
        {
            w.suspLengthPrev = w.suspLength;
            w.suspLength = suspToGround - w.radius;
            if (w.suspLength < 0.3f) w.suspLength = 0.3f;
            w.suspCompression = w.suspMaxLength - w.suspLength;
            w.position = w.suspPosition + Vector3f(0.0f, -w.suspLength, 0.0f);

            float springForce = w.suspCompression * w.suspStiffness;
            float dampingForce = ((w.suspLengthPrev - w.suspLength) * w.suspDamping) / dt;

            float normalForce = springForce + dampingForce;

            Vector3f upDir = w.transformation.up;
            Vector3f springForceVec = upDir * springForce;
            Vector3f dampingForceVec = upDir * dampingForce;

            rbody.applyForceAtPos(springForceVec, w.forcePosition);
            rbody.applyForceAtPos(dampingForceVec, w.forcePosition);

            Vector3f forwardDir = w.transformation.forward;
            Vector3f sideDir = w.transformation.right * w.dirCoef;

            float forwardForce = w.torque / w.radius;
            
            float forwardSpeed = dot(rbody.linearVelocity, w.transformation.forward);

            Vector3f radiusVector = w.forcePosition - rbody.position;
            Vector3f pointVelocity = rbody.linearVelocity + cross(rbody.angularVelocity, radiusVector);
            float sideSpeed = dot(pointVelocity, sideDir);
            
            float frictionCoef = 0.6f;
            if (sideSpeed > 0.05f)
                frictionCoef = 0.3f;
            if (sideSpeed > 0.8f)
                frictionCoef = 0.2f;
            if (sideSpeed > 0.9f)
                frictionCoef = 0.1f;
            if (sideSpeed > 1.0f)
                frictionCoef = 0.05f;
            if (sideSpeed > 2.0f)
                frictionCoef = 0.025f;
            if (sideSpeed > 3.0f)
                frictionCoef = 0.01f;
            
            float lateralForce = sideSpeed * normalForce * frictionCoef;
            
            rbody.applyForceAtPos(forwardDir * forwardForce, w.forcePosition);
            rbody.applyForceAtPos(-sideDir * lateralForce, w.forcePosition);

            inAir = false;

            w.isDrifting = abs(sideSpeed) > 1.0f;
        }
        
        if (!w.brake && !w.handbrake)
        {
            if (!inAir)
            {
                float forwardSpeed = dot(rbody.linearVelocity, rbody.transformation.forward) * 0.8f;
                w.rollSpeed = forwardSpeed / w.radius;
            }
            else
            {
                if (w.powered && abs(w.torque))
                    w.rollSpeed = w.torque * dt;

                float maxRollSpeed = 40.0f;
                if (w.rollSpeed > maxRollSpeed)
                    w.rollSpeed = maxRollSpeed;
                if (w.rollSpeed < -maxRollSpeed)
                    w.rollSpeed = -maxRollSpeed;
            }
            
            if (abs(w.rollSpeed) < 0.2f)
                w.rollSpeed = 0.0f;

            w.roll += radtodeg(w.rollSpeed) * dt;
            if (w.roll > 360.0f) w.roll -= 360.0f;
        }
        else if (!inAir)
            w.isDrifting = true;

        w.torque = 0.0f;
    }

    bool isMovingForward()
    {
        float forwardSpeed = dot(rbody.linearVelocity, rbody.transformation.forward);
        return forwardSpeed > 0.0f;
    }

    bool isMovingBackward()
    {
        float forwardSpeed = dot(rbody.linearVelocity, rbody.transformation.forward);
        return forwardSpeed < 0.0f;
    }

    bool isStopped()
    {
        float forwardSpeed = dot(rbody.linearVelocity, rbody.transformation.forward);
        return abs(forwardSpeed) <= EPSILON;
    }

    Vector3f position()
    {
        return rbody.position;
    }

    Quaternionf rotation()
    {
        return rbody.orientation;
    }

    void fixedStepUpdate(double dt)
    {
        foreach(i, w; wheels)
            updateWheel(w, dt);
        
        if (torqueAcc > 0.0f)
            torqueAcc -= 0.01f;
        else if (torqueAcc < 0.0f)
            torqueAcc += 0.01f;
        
        speed = rbody.linearVelocity.length;
    }

    override void update(double dt)
    {
        entity.position = rbody.position;
        entity.rotation = rbody.orientation; 
        entity.transformation = rbody.transformation;
        entity.invTransformation = entity.transformation.inverse;
    }
}

class CarView: EventListener, View
{
    VehicleController vehicle;
    Vector3f position;
    Vector3f offset;
    Matrix4x4f _trans;
    Matrix4x4f _invTrans;
    
    int prevMouseX;
    int prevMouseY;
    
    bool _active = true;

    this(EventManager emngr, VehicleController vehicle, Owner owner)
    {
        super(emngr, owner);

        this.vehicle = vehicle;
        offset = Vector3f(0.0f, 0.0f, -1.0f);
        position = vehicle.position + offset;
    }
    
    void active(bool v)
    {
        if (v)
        {
            prevMouseX = eventManager.mouseX;
            prevMouseY = eventManager.mouseY;
            SDL_SetRelativeMouseMode(SDL_TRUE);
        }
        else
        {
            SDL_SetRelativeMouseMode(SDL_FALSE);
            eventManager.setMouse(prevMouseX, prevMouseY);
        }
        
        _active = v;
    }
    
    bool active()
    {
        return _active;
    }

    void update(double dt)
    {
        processEvents();
        
        if (_active)
        {  
            float turn_m =  (eventManager.mouseRelX) * 0.1f;
            float pitch_m = (eventManager.mouseRelY) * 0.1f;
            
            auto q = rotationQuaternion!float(Axis.y, turn_m * dt) * 
                     rotationQuaternion!float(Axis.x, pitch_m * dt);
            offset = q.rotate(offset);
        }
        
        Vector3f tp = vehicle.position + vehicle.rotation.rotate(offset) * 6.0f;
        tp.y = vehicle.position.y + 3.0f;
        Vector3f d = tp - position;
        position += (d * 10.0f) * dt;

        _trans = lookAtMatrix(position, vehicle.position + Vector3f(0, 2, 0), Vector3f(0, 1, 0));
        _invTrans = _trans.inverse;
    }

    Matrix4x4f viewMatrix()
    {
        return _trans;
    }
    
    Matrix4x4f invViewMatrix()
    {
        return _invTrans;
    }
    
    Vector3f cameraPosition()
    {
        return position;
    }
}
