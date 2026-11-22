# Math Library: Float/Double Switching

The mechanism stays idiomatic per language rather than reaching for something exotic — the goal is comparing the languages, not comparing generic-programming cleverness.

| Language | Mechanism |
|---|---|
| **C++** | Template on scalar type: `template<typename T> struct Vec3;` with `using Vec3f = Vec3<float>; using Vec3d = Vec3<double>;`. Compile both instantiations into the benchmark binary for direct A/B comparison. |
| **C#** | Generics with a numeric constraint using .NET's generic math (`INumber<T>`): `struct Vec3<T> where T : INumber<T>`. Instantiate `Vec3<float>` and `Vec3<double>` side by side, no code duplication. |
| **Haskell** | Typeclass-polymorphic definition (`Vec3 a` with `RealFloat a =>` constraints), instantiated at `Float` and `Double`. Use `SPECIALIZE` pragmas to ensure GHC compiles specialized code rather than benchmarking dictionary-passing overhead. |

**Discipline:** the benchmark harness in each language runs the *same* set of operations (add, dot, cross, mat4 multiply, quaternion slerp, batch update) at both precisions, so "float vs double" and "language vs language" are two independent, comparable axes.
