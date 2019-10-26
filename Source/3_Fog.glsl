#iChannel0 "./Source/Textures/Pebbles 512x512 1ch uint8.png"
#iChannel0::MinFilter "NearestMipMapNearest"
#iChannel0::MagFilter "Nearest"
#iChannel0::WrapMode "Repeat"

float sdSphere(vec3 p, float r)
{
    return length(p)-r;
}

float sdPlane(vec3 p, vec4 n)
{
    return dot(p, n.xyz) + n.w;
}

//------------------------------------------------------------------

vec2 opU(vec2 d1, vec2 d2)
{
	return (d1.x < d2.x) ? d1 : d2;
}


//------------------------------------------------------------------

vec2 SDF(vec3 pos)
{
    vec2 res =     vec2(sdSphere(pos-vec3(3,-2.5,10), 2.5),          0.1);
    res = opU(res, vec2(sdSphere(pos-vec3(-3, -2.5, 10), 2.5),       2.0));
    res = opU(res, vec2(sdSphere(pos-vec3(0, 2.5, 10), 2.5),         5.0));
    res = opU(res, vec2(sdPlane(pos, vec4(0, 1, 0, 10)),            -0.5));
    
    return res;
}

vec3 calcNormal(vec3 pos)
{
	// Center sample
    float c = SDF(pos).x;
	// Use offset samples to compute gradient / normal
    vec2 eps_zero = vec2(0.001, 0.0);
    return normalize(vec3(
        SDF(pos + eps_zero.xyy).x,
        SDF(pos + eps_zero.yxy).x,
        SDF(pos + eps_zero.yyx).x) - c);
}

struct IntersectionResult
{
    float minDist;
    float mat;
};

IntersectionResult castRay(vec3 rayOrigin, vec3 rayDir)
{
    float tmax = 250.0;
    float t = 0.0;
    
    IntersectionResult result;
    result.mat = -1.0;
    
    for (int i = 0; i < 256; i++)
    {
        vec2 res = SDF(rayOrigin + rayDir * t);
        if (res.x < (0.0001*t))
        {
            result.minDist = t;
            return result;
        }
        else if (res.x > tmax)
        {
            result.mat = -1.0;
            result.minDist = -1.0;
            return result;
        }
        t += res.x;
        result.mat = res.y;
    }
    
    result.minDist = t;
    return result;
}

// http://iquilezles.org/www/articles/checkerfiltering/checkerfiltering.htm
float checkersGradBox(vec2 p)
{
    vec2 w = fwidth(p) + 0.001;
    vec2 i = 2.0*(abs(fract((p-0.5*w)*0.5)-0.5)-abs(fract((p+0.5*w)*0.5)-0.5))/w;
    return 0.5 - 0.5*i.x*i.y;
}

vec3 fogColor = vec3(0.30, 0.36, 0.60);

vec3 applyFog(vec3 rgb, float dist)
{
    float startDist = 80.0;
    float fogAmount = 1.0 - exp(-(dist-8.0) * (1.0/startDist));
    return mix(rgb, fogColor, fogAmount);
}

vec3 triplanarMap(vec3 surfacePos, vec3 normal, float scale)
{
	// Take projections along 3 axes, sample texture values from each projection, and stack into a matrix
	mat3x3 triMapSamples = mat3x3(
		texture(iChannel0, surfacePos.yz * scale).rgb,
		texture(iChannel0, surfacePos.xz * scale).rgb,
		texture(iChannel0, surfacePos.xy * scale).rgb
		);

	// Weight three samples by absolute value of normal components
	return triMapSamples * abs(normal);
}

vec3 render(vec3 rayOrigin, vec3 rayDir)
{
    vec3 col = fogColor - rayDir.y * 0.4;
    IntersectionResult res = castRay(rayOrigin, rayDir);
    float t = res.minDist;
    float m = res.mat;

    if (m > -1.0)
    {
        vec3 pos = rayOrigin + rayDir * t;
        
        if (m > -0.5)
        {
            col = col = vec3(0.18*m, 0.6-0.05*m, 0.2+0.2);

            vec3 N = calcNormal(pos);
            vec3 L = normalize(vec3(sin(iTime)*1.0, cos(iTime*0.5)+0.5, -0.5));
            // L is vector from surface point to light, N is surface normal. N and L must be normalized!
            float NoL = max(dot(N, L), 0.0);
            vec3 LDirectional = vec3(0.9, 0.9, 0.8) * NoL;
            vec3 LAmbient = vec3(0.03, 0.04, 0.1);
            vec3 diffuse = col * (LDirectional + LAmbient);
            
            if (m == 2.0)
            {
                diffuse *= triplanarMap(pos, N, 0.6);
            }
            
        	col = diffuse;
            
            // Visualize normals:
            //col = N * vec3(0.5) + vec3(0.5);
        }
        else
        {
            float grid = checkersGradBox(pos.xz*0.4) * 0.03 + 0.1;
            col = vec3(grid, grid, grid);
        }
        
       //col = applyFog(col, pos.z);
    }
    
    return col;
}
vec3 getCameraRayDir(vec2 uv, vec3 camPos, vec3 camTarget)
{
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
    result.x *= iResolution.x/iResolution.y;
    return result;
}

void mainImage(out vec4 fragColor, vec2 fragCoord)
{
    vec3 camPos = vec3(0, 0, -5);
#define ENABLE_CAMERA_MOVEMENT 1
#if ENABLE_CAMERA_MOVEMENT
    camPos += vec3(sin(iTime*0.5)*0.5, cos(iTime*0.5)*0.1, 0.0);
#endif
    vec3 at = vec3(0, 0, 0);
    
    vec2 uv = normalizeScreenCoords(fragCoord);
    vec3 rayDir = getCameraRayDir(uv, camPos, at);
    
    vec3 col = render(camPos, rayDir);
    
    col = pow(col, vec3(0.4545)); // Gamma correction (1.0 / 2.2)
    
    // Output to screen
    fragColor = vec4(col,1.0);
}