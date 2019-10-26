float sdSphere(vec3 p, float r)
{
    return length(p) - r;
}
 
float sdf(vec3 pos)
{
    float t = sdSphere(pos-vec3(0.0, 0.0, 10.0), 3.0);
     
    return t;
}

float castRay(vec3 rayOrigin, vec3 rayDir)
{
    float tmax = 20.0;
    float t = 0.0; // Stores current distance along ray
    
    for (int i = 0; i < 64; i++)
    {
        float res = sdf(rayOrigin + rayDir * t);
        if (res < (0.0001*t))
        {
            return t;
        }
        else if (res > tmax)
        {
            return -1.0;
        }
        t += res;
    }
    
    return -1.0;
}
// ------------------------------------------------------------------------------

vec3 render(vec3 rayOrigin, vec3 rayDir)
{
    vec3 col;
    float t = castRay(rayOrigin, rayDir);
 
    if (t == -1.0)
    {
        // Skybox colour
        col = vec3(0.30, 0.36, 0.60) - (rayDir.y * 0.7);
    }
    else
    {
        vec3 objectSurfaceColour = vec3(0.4, 0.8, 0.1);
        vec3 ambient = vec3(0.02, 0.021, 0.02);
        col = ambient * objectSurfaceColour;
    }
     
    return col;
}



vec3 getCameraRayDir(vec2 uv, vec3 camPos, vec3 camTarget)
{
    // Calculate camera's "orthonormal basis", i.e. its transform matrix components
    vec3 camForward = normalize(camTarget - camPos);
    vec3 camRight = normalize(cross(vec3(0.0, 1.0, 0.0), camForward));
    vec3 camUp = normalize(cross(camForward, camRight));
     
    float fPersp = 2.0;
    vec3 vDir = normalize(uv.x * camRight + uv.y * camUp + camForward * fPersp);
 
    return vDir;
}

vec2 normalizeScreenCoords(vec2 screenCoord)
{
    vec2 result = 2.0 * (screenCoord/iResolution.xy - 0.5);
    result.x *= iResolution.x/iResolution.y; // Correct for aspect ratio
    return result;
}





// compute pixel colour
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{   
    vec3 camPos = vec3(0, 0, -1);
    vec3 camTarget = vec3(0, 0, 0);

    vec2 uv = normalizeScreenCoords(fragCoord);
    vec3 rayDir = getCameraRayDir(uv, camPos, camTarget);   

    // compute signed distance to a colour
    vec3 col = render(camPos, rayDir);
    
    col = pow(col, vec3(0.4545)); // Gamma correction (1.0 / 2.2)

    fragColor = vec4(col, 1.0);// Output to screen
}

