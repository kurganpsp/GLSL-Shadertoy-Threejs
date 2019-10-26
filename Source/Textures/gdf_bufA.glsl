#iChannel0 "file://./gdf_bufA.png"

// created by florian berger (flockaroo) - 2017
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

vec3 getDistRes() { return vec3(floor(pow(iResolution.x*iResolution.y,.33)-1.)); }

//####################################################################
//## medusa geometry from https://www.shaderoo.org/?shader=ri47GG   ##

#define G (.5+sqrt(5./4.))
#ifndef PI2
#define PI2 (3.141592653*2.)
#endif
#define PI 3.141592653

// noise funcs by Morgan McGuire https://www.shadertoy.com/view/4dS3Wd

float hash(float n) { return fract(sin(n) * 1e4); }
float hash(vec2 p) { return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); }

float noise(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash(i), hash(i + 1.0), u);
}


float noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);

	// Four corners in 2D of a tile
	float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    // Simple 2D lerp using smoothstep envelope between the values.
	// return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
	//			mix(c, d, smoothstep(0.0, 1.0, f.x)),
	//			smoothstep(0.0, 1.0, f.y)));

	// Same code, with the clamps in smoothstep and common subexpressions
	// optimized away.
    vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

vec4 noise4(vec2 x) {
    return vec4(
        noise(x+vec2(0,0)),
        noise(x+vec2(0,.333)),
        noise(x+vec2(.333,0)),
        noise(x+vec2(0,.666))
    );
}

// get some 3d rand values by multiplying 2d rand in xy, yz, zx plane
vec4 getRand(vec3 pos)
{
    vec4 r = vec4(1.0);
    r*=noise4(pos.xy*256.)*2.-1.;
    r*=noise4(pos.xz)*2.-1.;
    r*=noise4(pos.zy)*2.-1.;
    return r;
}

vec4 getRand01Sph(vec3 pos)
{
    vec2 res = iResolution.xy;
    vec2 texc=((pos.xy*123.+pos.z)*res+.5)/res;
    return vec4(noise(texc*256.));
}

const vec4 p0 = vec4( 1, G, -G ,0 )/length(vec2(1,G));

vec3 icosaPosRaw[12] = vec3[] (
    -p0.xwz,  p0.xwy, -p0.xwy,  p0.xwz,
     p0.wyx, -p0.wzx,  p0.wzx, -p0.wyx,
     p0.yxw,  p0.zxw, -p0.zxw, -p0.yxw
);

int posIdx[60] = int[](
0,  6, 1,
0, 11, 6,
1,  4, 0,
1,  8, 4,
1, 10, 8,
2,  5, 3,
2,  9, 5,
2, 11, 9,
3,  7, 2,
3, 10, 7,
4,  8, 5,
4,  9, 0,
5,  8, 3,
5,  9, 4,
6, 10, 1,
6, 11, 7,
7, 10, 6,
7, 11, 2,
8, 10, 3,
9, 11, 0
);

// get icosahedron triangle
void getIcosaTri(int idx, out vec3 p1, out vec3 p2, out vec3 p3)
{
    float dot1 = -1000.0;
    float dot2 = -1000.0;
    float dot3 = -1000.0;
    int s1, s2, perm;

    int i1 = posIdx[idx*3+0];
    int i2 = posIdx[idx*3+1];
    int i3 = posIdx[idx*3+2];

    p1=icosaPosRaw[i1];
    p2=icosaPosRaw[i2];
    p3=icosaPosRaw[i3];
}


// subdivide 1 triangle into 4 triangles and give back closest triangle
void getTriSubDiv(int idx, inout vec3 p1, inout vec3 p2, inout vec3 p3)
{
    vec3 p4 = normalize(p1+p2);
    vec3 p5 = normalize(p2+p3);
    vec3 p6 = normalize(p3+p1);

    if     (idx==0) { p1=p1; p2=p4; p3=p6; }
    else if(idx==1) { p1=p6; p2=p5; p3=p3; }
    else if(idx==2) { p1=p6; p2=p4; p3=p5; }
    else if(idx==3) { p1=p4; p2=p2; p3=p5; }
}


int triStripIndex [6] = int [] (0,1,2,1,3,2);

#define mixSq(a,b,f) mix(a,b,cos(f*PI)*.5+.5)

//float homFact(float f) { return cos(f*PI)*.5+.5; }
//float homFact(float f) { return f<.5?f*f*2.:1.-(f-1.)*(f-1.)*2.; }
float homFact(float f) { f-=.5; return .5+(f-.9/.75*f*f*f)/(1.-.9/3.); }

void geomTangentCurve(vec3 pos1, vec3 pos2, vec3 tan1, vec3 tan2, float r1, float r2, 
                      int rSegNum, int tSegNum, int vIdx, out vec3 pos, out vec3 normal)
{
    float l = length(pos1-pos2);
    l*=.4;
    int i=(vIdx/3/2)%tSegNum;
    //{  // converted some loops into proper vertex index values
        float fact, fact2;
        fact=max(0.,homFact(float(i)/float(tSegNum))); // force >=0 because of sqrt below
        vec3 p1=mix(pos1+tan1*l*sqrt(fact ),pos2-tan2*l*sqrt(1.-fact ),fact );
        fact2=max(0.,homFact(float(i+1)/float(tSegNum))); // force >=0 because of sqrt below
        vec3 p2=mix(pos1+tan1*l*sqrt(fact2),pos2-tan2*l*sqrt(1.-fact2),fact2);

        vec3 ta = mix(tan1,tan2,fact);
        vec3 tn = mix(tan1,tan2,fact2);

        float dph=PI*2./float(rSegNum);
        //vec3 b1=normalize(vec3(ta.x,-ta.y,0));
        vec3 b1=normalize(cross(ta,p1));
        vec3 b2=normalize(cross(ta,b1));
        //vec3 b3=normalize(vec3(tn.x,-tn.y,0));
        vec3 b3=normalize(cross(tn,p2));
        vec3 b4=normalize(cross(tn,b3));
        float r_1 = mix(r1,r2,fact);
        float r_2 = mix(r1,r2,fact2);
        int j=(vIdx/3/2/tSegNum)%rSegNum;
        //{
            float ph  = float(j)*dph;
            float ph2 = ph+dph;
            vec3 v1 = p1+r_1*(b1*cos(ph )+b2*sin(ph ));
            vec3 v2 = p1+r_1*(b1*cos(ph2)+b2*sin(ph2));
            vec3 v3 = p2+r_2*(b3*cos(ph )+b4*sin(ph ));
            vec3 v4 = p2+r_2*(b3*cos(ph2)+b4*sin(ph2));
            vec3 v[4] = vec3[](v1,v2,v3,v4);
            pos = v[triStripIndex[vIdx%6]];
            normal = normalize(cross(v[1]-v[0],v[2]-v[0]));
        //}
    //}
}

float calcAngle(vec3 v1, vec3 v2)
{
    return acos(dot(v1,v2)/length(v1)/length(v2));
}

// distance to 2 torus segments in a triangle
// each torus segment spans from the middle of one side to the middle of another side
void geomTruchet(vec3 p1, vec3 p2, vec3 p3, float dz, int rSegNum, int tSegNum, int trNum, 
                 float radius, int idx, out vec3 pos, out vec3 normal )
{
    if (radius<0.0) radius=.45*dz;
    float d = 10000.0;
    float rnd =getRand01Sph(p1+p2+p3).x;
    float rnd2=getRand01Sph(p1+p2+p3).y;
    // random rotation of torus-start-edges
    if      (rnd>.75) { vec3 d=p1; p1=p2; p2=d; }
    else if (rnd>.50) { vec3 d=p1; p1=p3; p3=d; }
    else if (rnd>.25) { vec3 d=p2; p2=p3; p3=d; }
    
    vec3 p4 = p1*(1.f-dz);
    vec3 p5 = p2*(1.f-dz);
    vec3 p6 = p3*(1.f-dz);

    // FIXME: why is this necessary - very seldom actually!?
    bool xchg=false;
    if(dot(cross(p2-p1,p3-p1),p1)>0.0) {
        vec3 dummy;
        dummy=p2; p2=p3; p3=dummy;
        dummy=p5; p5=p6; p6=dummy;
        xchg=true;
    }

    float lp1 = length(p1);
    float lp4 = length(p4);
    
    float r,r1,r2,fact,ang,fullAng;
    vec3 n = normalize(cross(p2-p1,p3-p1));

    // torus segments:
    // actually i have to fade from one torus into another
    // because not all triangles are equilateral
    vec3 m;
//    std::vector <vec3> p;
    vec3 v1,v2,v3,v4,v5,v6;
    int tubeNum=rSegNum*tSegNum*2*3;
    int i=(idx/(tubeNum))%trNum;
    {
        if(i==0) { v1=p1; v2=p2; v3=p3; v4=p4; v5=p5; v6=p6; }
        if(i==1) { v1=p2; v2=p3; v3=p1; v4=p5; v5=p6; v6=p4; }
        if(i==2) { v1=p3; v2=p1; v3=p2; v4=p6; v5=p4; v6=p5; }
        //if(dot(cross(v2-v1,v3-v1),v1)>0.0) { vec3 dummy=v2; v2=v3; v3=dummy; }
        //if(dot(cross(v5-v4,v6-v4),v4)>0.0) { vec3 dummy=v5; v5=v6; v6=dummy; }

    	fullAng = calcAngle(v3-v1,v2-v1);
        //ang = calcAngle(pos2-v1,v2-v1);
        float dang=fullAng/float(tSegNum);
        //if (fullAng<.001) break;

        //float r1, r2;
        //r1=length(v2-v1)*.5f; r1=length(v3-v1)*.5f;
        vec3 pos1, pos2;
        pos1 = lp1*normalize(v2+v1); pos2 = lp4*normalize(v6+v4);
        // FIXME: why is this necessary - very seldom actually!? - see above
        if(xchg) {
            pos1 = lp1*normalize(v5+v4); pos2 = lp4*normalize(v3+v1);
        }
        if(rnd2>.25)
        {
            if(i==0) { pos1 = lp4*normalize(v5+v4); pos2 = lp4*normalize(v6+v4); }
            if(i==1) { pos1 = lp1*normalize(v2+v1); pos2 = lp1*normalize(v3+v1); }
        }
        vec3 tan1 = normalize(cross(v2-v1,v1));
        vec3 tan2 = normalize(cross(v3-v1,v1));
        geomTangentCurve(pos1,pos2,tan1,tan2,radius,radius,rSegNum,tSegNum,
                         idx%tubeNum,pos,normal);
    }
}

// final shape
void geom_medusa(int rNum, int tNum, int subdiv, int idx, out vec3 pos, out vec3 normal)
{
    vec3 p1,p2,p3;

    int icosaFaceNum = 20;
    int subDivNum = 4;
    
    int trNum = 3; // tubes per truchet segemnt
    int truchetNum=rNum*tNum*2*3*trNum; // 2 triangles * 3 vertices * trNum tubes
    
    //for(int i1=0;i1<icosaFaceNum;i1++)
    int idiv=truchetNum; for(int i=0;i<subdiv;i++) idiv*=subDivNum;
    getIcosaTri(idx/idiv, p1, p2, p3);
    int p_subDivNum_i = 1;
    for(int i=0;i<subdiv;i++)
    {
        idiv/=subDivNum;
        int isub = (idx/idiv)%subDivNum;
        getTriSubDiv(isub,p1,p2,p3);
        p_subDivNum_i*=subDivNum;
    }
    geomTruchet(p1,p2,p3,0.12/float(1+subdiv),rNum,tNum,trNum,-1.,idx%truchetNum,pos,normal);
    pos=(idx>icosaFaceNum*truchetNum*p_subDivNum_i)?vec3(0):pos;
    normal=(idx>icosaFaceNum*truchetNum*p_subDivNum_i)?vec3(0):normal;
}

//## end - medusa geom
//####################################################################

// this geometry will be converted to a distance field
#define TriNum 0x2000
void geometry( out vec3 pos, int vertIndex )
{
    /*pos = vec3(0);
    float l=float(vertIndex)*.01;
    pos = .5*(.97+.03*float(vertIndex%2))
          *sin(vec3(0,1.6,.707)+l*vec3(1,3,2)+iTime);*/

    vec3 normal;
    
    //torusGeom( pos, normal, vertIndex%TorusVertNum );
    
    geom_medusa(4,16,0,vertIndex,pos,normal); pos*=.7;
    
    //pos=pos.yzx;
}

vec2 triangleCoord( vec3 v2, vec3 v0, vec3 v1 )
{
    float dot00=dot(v0,v0);
    float dot01=dot(v0,v1);
    float dot02=dot(v0,v2);
    float dot11=dot(v1,v1);
    float dot12=dot(v1,v2);
    float denom = dot00*dot11-dot01*dot01;
    if(denom<0.00001) return vec2(-1,-1);
    vec2  rval;
    rval.x = (dot11 * dot02 - dot01 * dot12) / denom;
    rval.y = (dot00 * dot12 - dot01 * dot02) / denom;
    return rval;
}

// checks if a vertex lies within a certain triangle
bool inTriangle( vec3 pos, vec3 v1, vec3 v2, vec3 v3 )
{
    vec2 tc=triangleCoord( pos-v1, v2-v1, v3-v1 );
    return ( (tc.x>0.0f) && (tc.y>0.0f) && (tc.x+tc.y<1.0f) );
}

// returns actual distance to line in .y and on-line-parameter on .x 0->pos=0, 1->pos=v (>1 or <0 means off line)
vec2 calcLineDist(vec3 pos, vec3 v)
{
    vec2 rval;
    rval.x = dot(pos,v)/dot(v,v);
    rval.y = length(pos-rval.x*v);
    return rval;
}

// calculates the closest-distance-point to triangle v1,v2,v3 (in weights of the edge points)
vec3 calcDistPoint( vec3 pos, vec3 v1, vec3 v2, vec3 v3 )
{
    bool found = false;
    float dist = 1024.0;

    vec3 m = vec3(1,0,0);
    vec3 m1 = m.xyz;
    vec3 m2 = m.zxy;
    vec3 m3 = m.yzx;

    vec3 distpos;
#if 1
    // triangle (normal distance to plane)
    vec2 tc=triangleCoord( pos-v1, v2-v1, v3-v1 );
    if ( (tc.x>0.0f) && (tc.y>0.0f) && (tc.x+tc.y<1.0f) ) // check if normal-dist point is within triangle
    {
        distpos=tc.x*(m2-m1)+tc.y*(m3-m1)+m1;
        found = true;
    }
    if(found) return distpos;

    // edges (normal distance to line)
    vec2 linedist;
    linedist=calcLineDist(pos-v1,v2-v1); if( linedist.x>0.0 && linedist.x<1.0 && linedist.y<dist ) { dist=linedist.y; distpos=mix(m1,m2,linedist.x); found=true; }
    linedist=calcLineDist(pos-v2,v3-v2); if( linedist.x>0.0 && linedist.x<1.0 && linedist.y<dist ) { dist=linedist.y; distpos=mix(m2,m3,linedist.x); found=true; }
    linedist=calcLineDist(pos-v3,v1-v3); if( linedist.x>0.0 && linedist.x<1.0 && linedist.y<dist ) { dist=linedist.y; distpos=mix(m3,m1,linedist.x); found=true; }
    if(found) return distpos;
#endif
    // points (distance to edge-point)
    float actdist;
    actdist=length(pos-v1); if(actdist<dist) { dist=actdist; distpos=m1; found=true; }
    actdist=length(pos-v2); if(actdist<dist) { dist=actdist; distpos=m2; found=true; }
    actdist=length(pos-v3); if(actdist<dist) { dist=actdist; distpos=m3; found=true; }
    if(found) return distpos;

    return vec3(1,0,0);
}

float calcDist( vec3 pos, vec3 p1, vec3 p2, vec3 p3, vec3 n1, vec3 n2, vec3 n3, out vec3 d, out vec3 n )
{
    vec3 m = calcDistPoint(pos,p1,p2,p3);
    d = m.x*p1 + m.y*p2 + m.z*p3;
    n = m.x*n1 + m.y*n2 + m.z*n3;
    return length(pos-d);
}

// maked it a Signed Distance Field (works only with smooth normals for now)
uniform float signedField;

void mainImage( out vec4 fragColor, vec2 fragCoord )
{
    fragColor = texture(iChannel0,fragCoord/iResolution.xy);
    #define TrisAtOnce 16
    for(int i=0;i<TrisAtOnce;i++)
    {
    int frame=iFrame-((iResolution.x<400.)?1:60);
    int tri=frame*TrisAtOnce+i;
    if(tri>=TriNum) return;
    // the X/Y/Z-size of the 3d distance field (normally 3D-texture but here tiled in 2D)
    vec3 size = getDistRes();
    // return big distance if invalid triangle index (or init);
    if(frame<0) { fragColor=vec4(20,20,20,1); return; }
    
    // get the triangle
    vec3 p1,p2,p3;
    geometry(p1,int(tri)*3+0);
    geometry(p2,int(tri)*3+1);
    geometry(p3,int(tri)*3+2);
    
    // dont take 0-triangles into account
    if(p1==p2 || p1==p3 || p2==p3) { return; }
    
    // get the xyz texcoord in the 3d-texture for our actual fragment
    vec2 fbSize = iResolution.xy;
    vec2 gridSize = floor(fbSize/floor(size.xy));
    vec2 gridPos = floor(fragCoord.xy/floor(size.xy));
    // the texcoord
    vec3 pos01 = vec3(mod(fragCoord.xy,floor(size.xy)), gridPos.x+gridPos.y*gridSize.x)/floor(size);

    vec3 pos = pos01*2.0-vec3(1.0); // texcoord -> pos
    vec3 dpos;
    vec3 dnorm;
    vec3 n=normalize(cross(p2-p1,p3-p1));
    // get the distance
    float d = calcDist(pos, p1,p2,p3, n,n,n, dpos, dnorm);
    // negative for SDF if pos in -normal direction
    if(signedField>0.5 && dot(pos-dpos,dnorm)<0.0) d=-d;

    if (isinf(d)) d=2.;
    if (isnan(d)) d=2.;
    //if (d==0.)    d=2.;
    
    vec3 col = (d<0.0) ? vec3(1,-1,-1) : vec3(1); // red is truely signed, green and blue hold unsigned distfield
    // mask invalid screen regions (give them some blue-ish bg color)
    if(gridPos.x>=gridSize.x || pos01.z>1.) { d=2.; col=vec3(0,.15,.3); }
    
    // write final fragment distance * col
    fragColor = (d<fragColor.x)?vec4(d*col,1):fragColor;
    }
}

