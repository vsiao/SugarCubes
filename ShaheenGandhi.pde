import toxi.geom.Vec3D;
import toxi.geom.Matrix4x4;

class HelixPattern extends SCPattern {

  // Stores a line in point + vector form
  private class Line {
    private final PVector origin;
    private final PVector vector;

    Line(PVector pt, PVector v) {
      origin = pt;
      vector = v.get();
      vector.normalize();
    }

    PVector getPoint() {
      return origin;
    }

    PVector getVector() {
      return vector;
    }

    PVector getPointAt(final float t) {
      return PVector.add(origin, PVector.mult(vector, t));
    }

    boolean isColinear(final PVector pt) {
      PVector projected = projectPoint(pt);
      return projected.x==pt.x && projected.y==pt.y && projected.z==pt.z;
    }

    float getTValue(final PVector pt) {
      PVector subtraction = PVector.sub(pt, origin);
      return subtraction.dot(vector);
    }

    PVector projectPoint(final PVector pt) {
      return getPointAt(getTValue(pt));
    }

    PVector rotatePoint(final PVector pt, final float rads) {
      Vec3D axisVec3D = new Vec3D(vector.x, vector.y, vector.z);
      Vec3D originVec3D = new Vec3D(origin.x, origin.y, origin.z);
      Matrix4x4 mat = new Matrix4x4().identity()
        .rotateAroundAxis(axisVec3D, rads);
      Vec3D ptVec3D = new Vec3D(pt.x, pt.y, pt.z).sub(originVec3D);
      Vec3D rotatedPt = mat.applyTo(ptVec3D).add(originVec3D);
      return new PVector(rotatedPt.x, rotatedPt.y, rotatedPt.z);
    }
  }

  private class Helix {
    private final Line axis;
    private final float period; // period of coil
    private final float rotationPeriod; // animation period
    private final float radius; // radius of coil
    private final float girth; // girth of coil
    private final PVector referencePoint;
    private float phase;
    private PVector phaseNormal;

    Helix(Line axis, float period, float radius, float girth, float phase, float rotationPeriod) {
      this.axis = axis;
      this.period = period;
      this.radius = radius;
      this.girth = girth;
      this.phase = phase;
      this.rotationPeriod = rotationPeriod;

      // Generate a normal that will rotate to
      // produce the helical shape.
      PVector pt = new PVector(0, 1, 0);
      if (this.axis.isColinear(pt)) {
        pt = new PVector(0, 0, 1);
        if (this.axis.isColinear(pt)) {
          pt = new PVector(0, 1, 1);
        }
      }

      this.referencePoint = pt;

      // The normal is calculated by the cross product of the axis
      // and a random point that is not colinear with it.
      phaseNormal = axis.getVector().cross(referencePoint);
      phaseNormal.normalize();
      phaseNormal.mult(radius);
    }

    private void setPhase(float phase) {
      this.phase = phase;
      setPhaseNormalFromPhase();
    }

    Line getAxis() {
      return axis;
    }

    void step(int deltaMs) {
      // Rotate
      if (rotationPeriod != 0) {
        setPhase(phase + (deltaMs / rotationPeriod) * TWO_PI);
      }
    }

    PVector pointOnToroidalAxis(float t) {
      PVector p = axis.getPointAt(t);
      PVector middle = PVector.add(p, phaseNormal);
      return axis.rotatePoint(middle, (t / period) * TWO_PI);
    }

    color colorOfPoint(final PVector p) {
      // Find the appropriate point for the current rotation
      // of the helix.
      float t = axis.getTValue(projectedPoint);
      PVector toroidPoint = pointOnToroidalAxis(t);

      // The rotated point represents the middle of the girth of
      // the helix.  Figure out if the current point is inside that
      // region.
      float d = PVector.dist(p, toroidPoint);
      boolean inToroid = d < girth;

      // Soften edges by fading brightness
      float b = constrain(100*(1 - ((d-.5*girth)/(girth*.5))), 0, 100);
      return color((lx.getBaseHuef() + (360*(phase / TWO_PI)))%360, (inToroid ? 80 : 0), b);
    }
  }

  private final Helix h1;
  private final Helix h2;

  private final BasicParameter helix1On = new BasicParameter("H1ON", 1);
  private final BasicParameter helix2On = new BasicParameter("H2ON", 1);

  public HelixPattern(GLucose glucose) {
    super(glucose);

    addParameter(helix1On);
    addParameter(helix2On);

    h1 = new Helix(
      new Line(new PVector(100, 50, 70), new PVector(1,0,0)),
      700, // period
      50, // radius
      30, // girth
      0,  // phase
      10000); // rotation period (ms)
    h2 = new Helix(
      new Line(new PVector(100, 50, 70), new PVector(1,0,0)),
      700,
      50,
      30,
      PI,
      10000);

    // TODO(shaheen) calculate line segments between
    // toroidal points selected by stepping the
    // parameterized t value.  select base pairs and
    // associated colors.  lerp between colors for each
    // base pair to produce a DNA effect.

  }

  void run(int deltaMs) {
    boolean h1on = helix1On.getValue() > 0.5;
    boolean h2on = helix2On.getValue() > 0.5;

    h1.step(deltaMs);
    h2.step(deltaMs);

    for (Point p : model.points) {
      color h1c = color(0,0,0);
      color h2c = color(0,0,0);

      if (h1on) {
        h1c = h1.colorOfPoint(new PVector(p.x,p.y,p.z));
      }

      if (h2on) {
        h2c = h2.colorOfPoint(new PVector(p.x,p.y,p.z));
      }

      // The helices are positioned to not overlap.  If that changes,
      // a better blending formula is probably needed.
      colors[p.index] = blendColor(h1c, h2c, ADD);
    }
  }
}

