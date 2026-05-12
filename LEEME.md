# DotnetSemVerPs

Herramientas PowerShell para administrar versiones SemVer en archivos de proyecto .NET.

`DotnetSemVerPs` actualiza propiedades de version en archivos `.csproj`, soporta flujos estables, prerelease y metadata de build, genera build numbers como epoch UTC, e incluye un script de pruebas para validar escenarios de versionado.

Version actual del script: `1.15.2`.

### Funcionalidades

- Actualiza archivos `.csproj` directamente.
- Guarda el valor SemVer completo en `Version`.
- Guarda el nucleo numerico de version en `NumVer`.
- Soporta versiones estables, prerelease, metadata de build, y prerelease junto con metadata de build.
- Genera `BuildNumber` como epoch UTC en cada actualizacion de version.
- Crea automaticamente las propiedades de version faltantes.
- Puede crear y subir commits de release y tags SemVer con `-Release`.
- Puede validar un string SemVer externo con `-Validate -SemVer <semver>`.
- Puede ejecutar el script local de pruebas con `-Tests`.
- Incluye un script de pruebas con escenarios comunes de versionado.

### Changelog

Ver [CHANGELOG.md](CHANGELOG.md) para las notas de release.

La documentacion en ingles esta disponible en [README.md](README.md).

### Propiedades De Version

El script administra estas propiedades en el `.csproj` objetivo:

```xml
<Version>7.3.1-rc2.1+Build.1777848010</Version>
<NumVer>7.3.1</NumVer>
<BuildNumber>1777848010</BuildNumber>
<PrereleaseName>rc2.1</PrereleaseName>
<BuildName>Build</BuildName>
<IsPrerelease>True</IsPrerelease>
<IsBuild>True</IsBuild>
```

| Propiedad | Descripcion |
|---|---|
| `Version` | Valor SemVer completo generado. |
| `NumVer` | Version numerica solamente: `Major.Minor.Patch`. |
| `BuildNumber` | Epoch UTC generado en cada actualizacion de version. |
| `PrereleaseName` | Identificador prerelease, por ejemplo `rc`, `rc2`, `rc2.1`. |
| `BuildName` | Prefijo de metadata de build, por ejemplo `Build`. |
| `IsPrerelease` | Indica si debe usarse prerelease. |
| `IsBuild` | Indica si debe usarse metadata de build. |

Cuando `Version` y `NumVer` faltan o estan vacios, el script inicia desde
`0.1.0` como version inicial de desarrollo. Luego aplica el tipo solicitado
desde esa base, por lo que `-Type Patch` produce `0.1.1`.

### Salida SemVer

Formatos soportados:

```text
7.3.0
7.3.0-rc
7.3.0+Build.4545454
7.3.0-rc2+Build.995269
7.3.0-rc2.1+Build.995269
```

### Uso

Mostrar ayuda:

```powershell
./Version.ps1 -Usage
```

Mostrar la version del script:

```powershell
./Version.ps1 -Version
```

Leer o crear la version actual del proyecto:

```powershell
$projectVersion = & ./Version.ps1 -ProjectPath ./MyProject.csproj -Version
```

Leer o crear el build number actual del proyecto:

```powershell
$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber
```

Refrescar el build number actual del proyecto:

```powershell
$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber -Refresh
```

Leer la version del script:

```powershell
$scriptVersion = & ./Version.ps1 -Version
```

Validar un valor SemVer externo:

```powershell
$validated = & ./Version.ps1 -Validate -SemVer 1.2.3-rc.1+Build.5
```

Imprimir detalles de validacion manteniendo limpia la salida capturable:

```powershell
$validated = & ./Version.ps1 -Validate -SemVer 1.2.3-rc.01 -Detailed
```

Ejecutar el script local de pruebas:

```powershell
./Version.ps1 -Tests
```

`-Usage` tiene su propio parameter set. `-Version` puede usarse solo para retornar
la version del script, o con `-ProjectPath` para retornar el valor `Version` del
`.csproj`. Si `Version` falta o esta vacio en el proyecto, el script crea
`Version` y `NumVer` con `0.1.0`, guarda el proyecto y retorna `0.1.0`.
`-BuildNumber` puede usarse con `-ProjectPath` para retornar el valor
actual `BuildNumber` del `.csproj`; si falta o esta vacio, el script crea uno
con epoch UTC y lo retorna. Agrega `-Refresh` para forzar un nuevo valor epoch UTC
y guardarlo en el proyecto.

`-Validate -SemVer <semver>` retorna la misma version cuando es SemVer 2.0.0
valido, o salida vacia cuando es invalida. `-Detailed` escribe la razon de
validacion al host para que asignaciones como `$validated = & ./Version.ps1 ...`
capturen solo la version o un valor vacio. La validacion usa la expresion regular
recomendada por SemVer.org con named groups, adaptada a la sintaxis de named
groups de .NET.

`-Tests` ejecuta `Version-Tests.ps1` cuando existe junto a `Version.ps1`. Si el
archivo de pruebas no existe, el script imprime que los tests no fueron
encontrados.

Sintaxis de versionado:

```powershell
./Version.ps1 -ProjectPath <path.csproj> -Type <Major|Minor|Patch> [options]
```

`-ProjectPath` y `-Type` son requeridos para el parameter set de versionado.

Crear un commit local de release y tag:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Release
```

`-Release` tiene su propio parameter set y debe usarse sin `-Type`; la version
de release se calcula desde Conventional Commits. Primero localiza el repositorio Git que contiene el `.csproj` buscando
hacia arriba desde la carpeta del archivo de proyecto. El proyecto puede estar
anidado cualquier cantidad de carpetas dentro del repositorio; solo necesita
estar dentro de un repo Git valido. Luego el script requiere un working tree de
Git completamente limpio antes de iniciar: sin archivos untracked, sin cambios
unstaged, y sin cambios staged esperando commit.

Cuando el ultimo tag Git alcanzable es SemVer valido, `-Release` calcula la
siguiente version desde los commits posteriores a ese tag en orden cronologico
usando Conventional Commits: breaking changes incrementa major, `feat`
incrementa minor, y `fix` o `perf` incrementa patch. Los mensajes que no son
Conventional Commits se ignoran en el calculo; tipos Conventional Commit que no
corresponden a un incremento, como `docs` o `test`, no cambian la version. Si
ningun commit incrementa la version, la version generada queda igual al ultimo
tag SemVer y el script mueve ese tag existente al nuevo commit de release. Si el
ultimo tag alcanzable no es SemVer valido, el script
trata el repositorio como si no tuviera tags SemVer, inicia desde la version
actual del proyecto y analiza los commits posteriores a ese tag. Si no existe
ningun tag, el script inicia desde la version actual del proyecto y analiza todos
los commits.

Si el release es valido, el script actualiza el `.csproj`, agrega al stage solo
ese archivo de proyecto, hace commit solo de ese archivo con `tag: <version>`,
crea o mueve un tag con el nombre exacto del valor SemVer generado, y luego sube
el branch actual y ese tag a `origin`.

### Conventional Commits En Release

Solo los mensajes Conventional Commit se consideran durante el calculo de version
de `-Release`.

| Mensaje de commit | Cambio de version | Ejemplo desde `0.1.0` |
|---|---|---|
| `feat: ...` | Minor | `0.2.0` |
| `fix: ...` | Patch | `0.1.1` |
| `perf: ...` | Patch | `0.1.1` |
| `feat!: ...` o `feat(scope)!: ...` | Major | `1.0.0` |
| Cuerpo del mensaje con `BREAKING CHANGE:` | Major | `1.0.0` |
| `docs: ...` | Sin cambio | `0.1.0` |
| `test: ...` | Sin cambio | `0.1.0` |
| `chore: ...`, `refactor: ...`, `style: ...`, `build: ...`, `ci: ...` | Sin cambio | `0.1.0` |
| `tag: <version>` | Sin cambio | `0.1.0` |
| Cualquier mensaje que no sea Conventional Commit | Ignorado | `0.1.0` |

El calculo es acumulativo y cronologico. Por ejemplo, iniciando en `0.1.0`:
`feat` -> `0.2.0`, `fix` -> `0.2.1`, `perf` -> `0.2.2`, `docs` ->
`0.2.2`, breaking change -> `1.0.0`, luego `feat` -> `1.1.0`.

Previsualizar sin guardar:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -WhatIf
```

`-WhatIf` imprime el estado actual del proyecto y el siguiente estado generado
sin escribir cambios en el archivo `.csproj`.

Ejemplo de salida preview:

```text
┌────────────────────────────┐
│          Current           │
└────────────────────────────┘
Version: 7.3.0
NumVer: 7.3.0

┌────────────────────────────┐
│            Next            │
└────────────────────────────┘
Version: 7.3.1
NumVer: 7.3.1
WhatIf: True
```

### Tipos De Version

#### Patch

Incrementa patch y reutiliza valores prerelease/build guardados cuando existen.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch
```

Ejemplo:

```text
Before Version: 7.3.0
Before NumVer: 7.3.0

After Version: 7.3.1
After NumVer: 7.3.1
```

#### Minor

Incrementa minor, reinicia patch y reutiliza valores prerelease/build guardados cuando existen.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor
```

Ejemplo:

```text
7.3.0 -> 7.4.0
```

#### Major

Incrementa major, reinicia minor/patch y reutiliza valores prerelease/build guardados cuando existen.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Major
```

Ejemplo:

```text
7.3.9 -> 8.0.0
```

#### Stable

Promueve la version numerica actual a estable sin incrementar `NumVer`.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Stable
```

Ejemplo:

```text
7.3.0-rc2+Build.123 -> 7.3.0
7.3.0-rc2.1 -> 7.3.0
7.3.0+Build.123 -> 7.3.0
```

### Versiones Prerelease

Usa `-IsPrerelease` y `-PrereleaseName`.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor -IsPrerelease -PrereleaseName rc
```

Salida de ejemplo:

```text
Version: 7.4.0-rc
NumVer: 7.4.0
BuildNumber: 1777848010
IsPrerelease: True
IsBuild: False
PrereleaseName: rc
BuildName:
```

Cuando se usa `-IsPrerelease`, `-PrereleaseName` es requerido y no puede estar vacio ni contener solo espacios. Los nombres prerelease guardados se reutilizan en futuras ejecuciones `Major`, `Minor` y `Patch` hasta que `-IsNotPrerelease` o un flujo stable los limpie.

Ejemplo invalido:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsPrerelease
```

Error esperado:

```text
PrereleaseName is required when IsPrerelease is used.
```

### Metadata De Build

Usa `-IsBuild` y `-BuildName`.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild -BuildName Build
```

Salida de ejemplo:

```text
Version: 7.3.1+Build.1777848010
NumVer: 7.3.1
BuildNumber: 1777848010
IsPrerelease: False
IsBuild: True
PrereleaseName:
BuildName: Build
```

Cuando se usa `-IsBuild`, `-BuildName` es requerido y no puede estar vacio ni contener solo espacios. Los nombres build guardados se reutilizan en futuras ejecuciones `Major`, `Minor` y `Patch` hasta que `-IsNotBuild` o un flujo stable los limpie.

Ejemplo invalido:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild
```

Error esperado:

```text
BuildName is required when IsBuild is used.
```

### Prerelease Y Metadata De Build

```powershell
./Version.ps1 `
  -ProjectPath ./MyProject.csproj `
  -Type Patch `
  -IsPrerelease `
  -PrereleaseName rc2.1 `
  -IsBuild `
  -BuildName Build
```

Salida de ejemplo:

```text
Version: 7.3.1-rc2.1+Build.1777848010
NumVer: 7.3.1
BuildNumber: 1777848010
IsPrerelease: True
IsBuild: True
PrereleaseName: rc2.1
BuildName: Build
```

### Flags Negativos

Los flags negativos sobreescriben los flags positivos y limpian el valor guardado correspondiente en el proyecto.

#### Deshabilitar Prerelease

```powershell
./Version.ps1 `
  -ProjectPath ./MyProject.csproj `
  -Type Patch `
  -IsPrerelease `
  -IsNotPrerelease `
  -IsBuild `
  -BuildName Build
```

Resultado esperado:

```text
Version: 7.3.1+Build.<BuildNumber>
IsPrerelease: False
IsBuild: True
```

#### Deshabilitar Build

```powershell
./Version.ps1 `
  -ProjectPath ./MyProject.csproj `
  -Type Patch `
  -IsPrerelease `
  -PrereleaseName rc `
  -IsBuild `
  -IsNotBuild
```

Resultado esperado:

```text
Version: 7.3.1-rc
IsPrerelease: True
IsBuild: False
```

### Switch Stable

`-Stable` tambien puede combinarse con `Major`, `Minor` o `Patch` para
incrementar la version numerica y forzar que la version generada sea estable.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -Stable
```

Ejemplo:

```text
Before Version: 7.3.0-rc
Before NumVer: 7.3.0

After Version: 7.3.1
After NumVer: 7.3.1
```

### Reglas

- `Version` guarda el valor SemVer final.
- `NumVer` guarda solamente `Major.Minor.Patch`.
- Valores faltantes de `Version` y `NumVer` inician desde `0.1.0`.
- `BuildNumber` se recalcula en cada actualizacion de version.
- `Major`, `Minor` y `Patch` reutilizan valores `PrereleaseName` y `BuildName` guardados cuando existen.
- `Type` acepta solamente `Major`, `Minor` o `Patch`.
- `-Stable` solo promueve sin incrementar `NumVer`.
- `-Type <Major|Minor|Patch> -Stable` incrementa y luego limpia prerelease/build.
- `-Release` requiere que la carpeta del `.csproj`, o alguna carpeta padre, sea un repositorio Git valido.
- `-Release` debe usarse sin `-Type`; las versiones de release se calculan desde Conventional Commits.
- `-Release` requiere un working tree de Git completamente limpio antes de iniciar.
- `-Release` falla cuando existen archivos untracked, cambios unstaged, o cambios staged.
- `-Release` calcula la version de release desde Conventional Commits cronologicos desde el ultimo tag SemVer cuando existe.
- `-Release` inicia desde la version del proyecto y analiza commits despues del ultimo tag cuando ese tag no es SemVer.
- `-Release` inicia desde la version del proyecto y analiza todos los commits cuando no existe ningun tag.
- `-Release` mueve el ultimo tag SemVer al commit de release cuando ningun commit incrementa la version.
- `-Release` agrega al stage y commitea solo el cambio de version del proyecto con `tag: <version>`, crea o mueve el tag SemVer, y luego sube el branch actual y el tag a `origin`.
- `-IsPrerelease` requiere un `-PrereleaseName` no vacio.
- `-IsBuild` requiere un `-BuildName` no vacio.
- `-IsNotPrerelease` sobreescribe `-IsPrerelease` y limpia `PrereleaseName` guardado.
- `-IsNotBuild` sobreescribe `-IsBuild` y limpia `BuildName` guardado.
- `-WhatIf` previsualiza los valores actuales y siguientes generados sin guardar el archivo de proyecto.
- `-Usage` pertenece a un parameter set exclusivo y no puede combinarse con parametros de versionado.
- `-Version` retorna la version del script cuando se usa solo.
- `-ProjectPath <path.csproj> -Version` retorna el valor `Version` actual del proyecto y crea `Version`/`NumVer` como `0.1.0` cuando falta.
- `-ProjectPath <path.csproj> -BuildNumber` retorna el valor `BuildNumber` actual del proyecto y lo crea si falta.
- `-ProjectPath <path.csproj> -BuildNumber -Refresh` crea un nuevo valor `BuildNumber` del proyecto y lo retorna.
- `-Validate -SemVer <semver>` valida un string SemVer externo y retorna solo la version valida o salida vacia.
- `-Tests` ejecuta `Version-Tests.ps1` cuando el archivo existe.
- Los valores `Version` generados se validan contra la expresion regular de SemVer.org antes de guardarse.
- `PrereleaseName` y `BuildName` deben ser listas de identificadores SemVer validas antes de usarse para generar `Version`.

### Ejecutar Pruebas

Ejecutar:

```powershell
./Version-Tests.ps1
```

El script de pruebas crea archivos `.csproj` temporales bajo la carpeta temp del
sistema, ejecuta `Version.ps1` contra ellos, valida los resultados y elimina los
archivos temporales al finalizar.

Las pruebas de release con Git crean repositorios temporales aislados fuera de
este proyecto. Tambien se ejecutan con valores temporales de entorno Git para
`GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM`, `HOME`, `USERPROFILE` y
`XDG_CONFIG_HOME`, por lo que no dependen de este repositorio ni de la
configuracion Git del usuario.

Salida final esperada:

```text
All tests passed.
```

Cada prueba imprime el comando ejecutado, el estado de version antes/despues, y
un marcador verde `TEST <actual>/<total> PASS` antes de la linea separadora. Si
una prueba se detiene antes de finalizar, el marcador se imprime en rojo como
`FAIL`.

Ejemplo de salida de pruebas:

```text
./Version.ps1 -ProjectPath /path/to/MyProject.csproj -Stable
Type: <empty>
Params: Stable=True
┌────────────────────────────┐
│           Before           │
└────────────────────────────┘
Version: 7.3.0-rc2+Build.123
NumVer: 7.3.0
IsPrerelease: True
PrereleaseName: rc2
IsBuild: True
BuildName: Build
┌────────────────────────────┐
│           After            │
└────────────────────────────┘
Version: 7.3.0
NumVer: 7.3.0
IsPrerelease: False
PrereleaseName:
IsBuild: False
BuildName:
TEST 16/53 PASS
────────────────────────────────────────────────────────────
```

Las pruebas cubren:

- salida de usage
- combinaciones invalidas del parameter set `-Usage`
- salida de version del script
- salida de validacion SemVer
- ejecucion del parametro `-Tests`
- combinaciones invalidas del parameter set `-Version`
- salida de version del proyecto
- salida de version generada del proyecto
- combinaciones invalidas de `-Version` del proyecto
- salida de build number del proyecto
- salida de build number generado del proyecto
- salida de build number refrescado del proyecto
- combinaciones invalidas de `-BuildNumber` del proyecto
- preview con `-WhatIf` sin guardar
- creacion de commit y tag de release
- calculo de version de release desde Conventional Commits cronologicos
- release ignorando mensajes que no son Conventional Commits
- movimiento del tag de release cuando ningun Conventional Commit incrementa la version
- calculo de release desde la version del proyecto cuando el ultimo tag no es SemVer
- calculo de release desde la version del proyecto cuando no existe ningun tag
- push del branch actual y tag de release a `origin`
- release desde un proyecto anidado dentro de un repositorio
- fallo de release antes de guardar cuando existen archivos untracked
- fallo de release antes de guardar cuando existen cambios unstaged
- fallo de release antes de guardar cuando existen cambios staged
- alcance del commit de release limitado al archivo de proyecto actualizado
- promocion a stable
- promocion a stable desde prerelease
- promocion a stable desde metadata de build
- incrementos patch/minor/major
- reutilizacion de valores prerelease/build guardados durante incrementos patch/minor/major
- generacion de prerelease
- generacion de metadata de build
- generacion de prerelease + metadata de build
- validacion de nombre prerelease requerido
- validacion de nombre build requerido
- validacion de identificadores prerelease/build invalidos
- precedencia de flags negativos
- limpieza de valores prerelease/build guardados con flags negativos
