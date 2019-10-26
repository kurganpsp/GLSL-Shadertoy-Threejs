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

float opU(float d1, float d2)
{
	return min(d1, d2);
}

//------------------------------------------------------------------

float SDF(vec3 pos)
{
    float t =    sdSphere(pos-vec3(3,-2.5,10), 2.5);
    t = opU(t, sdSphere(pos-vec3(-3, -2.5, 10), 2.5));
    t = opU(t, sdSphere(pos-vec3(0, 2.5, 10), 2.5));
    t = opU(t, sdPlane(pos, vec4(0, 1, 0, 5.5)));
    return t;
}

vec3 calcNormal(vec3 pos)
{
	// Center sample
    float c = SDF(pos);
	// Use offset samples to compute gradient / normal
    vec2 eps_zero = vec2(0.001, 0.0);
    return normalize(vec3(
        SDF(pos + eps_zero.xyy),
        SDF(pos + eps_zero.yxy),
        SDF(pos + eps_zero.yyx)) - c);
}

float castRay(vec3 rayOrigin, vec3 rayDir)
{
    float t = 0.0; // Stores current distance along ray
    
    for (int i = 0; i < 512; i++)
    {
        float res = SDF(rayOrigin + rayDir * t);
        if (res < (0.0001*t))
        {
            return t;
        }
        t += res;
    }
    
    return -1.0;
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
    vec3 col;

    float t = castRay(rayOrigin, rayDir);
    if (t == -1.0)
    {
       col = vec3(0.30, 0.36, 0.60) - rayDir.y * 0.4;
    }
    else
    {
        vec3 objectSurfaceCol = vec3(0.8, 0.9, 0.9);
        
        vec3 pos = rayOrigin + rayDir * t;
        vec3 N = calcNormal(pos);
        vec3 L = normalize(vec3(sin(iTime)*1.0, cos(iTime*0.5)+0.5, -0.5));

        // L is vector from surface point to light, N is surface normal. N and L must be normalized!
        float NoL = max(dot(N, L), 0.0);
        vec3 LDirectional = vec3(1.80,1.27,0.99) * NoL;
        vec3 LAmbient = vec3(0.03, 0.04, 0.1);
        vec3 diffuse = objectSurfaceCol * (LDirectional + LAmbient);


        vec3 textureSample = triplanarMap(pos, N, 1.0);
        diffuse *= textureSample;

        col = diffuse;

    }
    
    // Visualize normals:
  	//col = N * vec3(0.5) + vec3(0.5);
    
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
    vec3 camPos = vec3(0, 0, -1);
    vec3 at = vec3(0, 0, 0);
    
    vec2 uv = normalizeScreenCoords(fragCoord);
    vec3 rayDir = getCameraRayDir(uv, camPos, at);
    
    vec3 col = render(camPos, rayDir);
    
    col = pow(col, vec3(0.4545)); // Gamma correction (1.0 / 2.2)
    
    fragColor = vec4(col,1.0);
}