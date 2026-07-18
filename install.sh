#!/bin/bash
set -e

if ! command -v node &> /dev/null; then
    exit 1
fi

mkdir -p dist
mkdir -p assets
mkdir -p view
mkdir -p controller
mkdir -p model
mkdir -p routes

BASE_URL="https://raw.githubusercontent.com/abinashmofficial/abilang/master-v1"

cat << 'EOF' > package.json
{
  "name": "abilang",
  "version": "1.0.0",
  "description": "The Progressive Scripting Language",
  "main": "dist/index.js",
  "bin": {
    "abi": "./dist/cli.js"
  },
  "scripts": {
    "start": "node dist/cli.js",
    "web": "node server.js"
  },
  "dependencies": {},
  "devDependencies": {}
}
EOF

for file in cli.js index.js interpreter.js lexer.js parser.js types.js; do
    curl -fsSL "$BASE_URL/dist/$file" -o "dist/$file"
done

cat << 'EOF' > view/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AbiLang - The Progressive Scripting Language</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Fira+Code:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="../assets/theme.css?v=1.2">
    <link rel="stylesheet" href="../assets/style.css?v=1.2">
</head>
<body>
    <button id="theme-toggle" class="theme-toggle-floating" title="Toggle Light/Dark Theme">
        <span id="theme-toggle-icon">☀</span>
    </button>

    <div id="portal-view" class="portal-screen">
        <nav class="portal-nav">
            <div class="nav-container">
                <div class="nav-logo">
                    <div class="abi-logo-badge">A</div>
                    <span class="nav-title">Abi<span>Lang</span></span>
                </div>
            </div>
        </nav>

        <main class="portal-hero">
            <div class="hero-container">
                <div class="hologram-overlay"></div>
                <div class="mockup-container" style="text-align:center; margin: 20px 0;">
                    <div class="dash-circle">
                        <div class="dash-text">Abi</div>
                    </div>
                </div>

                <div class="tagline-badge">AbiLang v1.1.0 (Cloud Release)</div>
                <h1 class="hero-title">
                    The Progressive <br>
                    <span>Scripting Language</span>
                </h1>
                <p class="hero-subtitle">
                    An approachable, highly performant and versatile scripting language designed for <strong>Abinash</strong>, running natively on all platform engines.
                </p>
                <div class="hero-actions">
                    <button id="launch-btn" class="btn btn-vue-primary">
                        Get Started
                        <svg class="icon-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                            <line x1="5" y1="12" x2="19" y2="12"></line>
                            <polyline points="12 5 19 12 12 19"></polyline>
                        </svg>
                    </button>
                    <a href="file:///var/www/personal/new-lang/README.md" target="_blank" class="btn btn-vue-secondary">View Docs</a>
                </div>
            </div>
        </main>

        <footer class="hud-footer">
            <span><a href="#" id="view-portal-link" style="color: var(--vue-green); text-decoration: none;">View Landing Portal</a></span>
            <span>Progressive Language Platform</span>
            <span>Made for Abinash</span>
        </footer>
    </div>

    <script src="../assets/abilang.min.js?v=1.2"></script>
    <script src="../assets/app.js?v=1.2"></script>
</body>
</html>
EOF

cat << 'EOF' > server.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { Interpreter, BuiltinFunction } = require('./dist/interpreter');
const { Lexer } = require('./dist/lexer');
const { Parser } = require('./dist/parser');

const routes = [];
const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'text/javascript',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml'
};

class ServerIO {
    print(msg) {}
    async input(prompt) { return ""; }
}

async function startServer() {
    const io = new ServerIO();
    const interpreter = new Interpreter(io);

    interpreter.globals.define("route", new BuiltinFunction(4, async (args) => {
        routes.push({
            method: String(args[0]).toLowerCase(),
            path: String(args[1]),
            action: String(args[2]),
            name: String(args[3])
        });
        return null;
    }));

    const routeFile = path.resolve('routes/route.abi');
    if (fs.existsSync(routeFile)) {
        const source = fs.readFileSync(routeFile, 'utf8');
        const lexer = new Lexer(source);
        const parser = new Parser(lexer.tokenize());
        await interpreter.interpret(parser.parse());
    }

    const server = http.createServer(async (req, res) => {
        const urlPath = req.url.split('?')[0];
        
        if (urlPath.startsWith('/assets/')) {
            const filePath = path.join(__dirname, urlPath);
            if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
                const ext = path.extname(filePath);
                res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'text/plain' });
                res.end(fs.readFileSync(filePath));
                return;
            }
        }

        const route = routes.find(r => r.method === req.method.toLowerCase() && r.path === urlPath);
        if (route) {
            const actionName = route.action.split('@')[1];
            const controllerFunc = interpreter.globals.get(actionName);
            if (controllerFunc && typeof controllerFunc.call === 'function') {
                const viewFile = await controllerFunc.call(interpreter, []);
                const filePath = path.join(__dirname, viewFile);
                if (fs.existsSync(filePath)) {
                    res.writeHead(200, { 'Content-Type': 'text/html' });
                    res.end(fs.readFileSync(filePath));
                    return;
                }
            }
        }

        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    });

    server.listen(8080, '127.0.0.1', () => {
        console.log('Server running at http://127.0.0.1:8080/');
    });
}

startServer().catch(err => {
    console.error(err);
    process.exit(1);
});
EOF

cat << 'EOF' > controller/controller.abi
func index() {
    return "view/index.html"
}
EOF

cat << 'EOF' > model/model.abi
func data() {
    return "Model data"
}
EOF

cat << 'EOF' > routes/route.abi
include("controller/controller.abi")
route("get", "/", "controller@index", "home")
EOF

curl -fsSL "$BASE_URL/web/app.js" -o assets/app.js
curl -fsSL "$BASE_URL/web/style.css" -o assets/style.css
curl -fsSL "$BASE_URL/web/theme.css" -o assets/theme.css
curl -fsSL "$BASE_URL/web/dist/abilang.min.js" -o assets/abilang.min.js

echo '#!/usr/bin/env node' | cat - dist/cli.js > temp && mv temp dist/cli.js
chmod +x dist/cli.js

node -e '
const fs = require("fs");
let content = fs.readFileSync("dist/interpreter.js", "utf8");
if (!content.includes("globals.define(\"include\"")) {
    content = content.replace("this.globals.define(\"render_ui\", new BuiltinFunction(1, async (args) => {\n            const uiElement = args[0];\n            if (this.io && \"renderUI\" in this.io && typeof this.io.renderUI === \"function\") {\n                await this.io.renderUI(uiElement);\n            }\n            else {\n                this.io.print(`[UI Render Log] ${JSON.stringify(uiElement, null, 2)}\\n`);\n            }\n            return null;\n        }));\n    }", `this.globals.define("render_ui", new BuiltinFunction(1, async (args) => {
            const uiElement = args[0];
            if (this.io && "renderUI" in this.io && typeof this.io.renderUI === "function") {
                await this.io.renderUI(uiElement);
            }
            else {
                this.io.print(\`[UI Render Log] \${JSON.stringify(uiElement, null, 2)}\\n\`);
            }
            return null;
        }));
        this.globals.define("include", new BuiltinFunction(1, async (args) => {
            const filePath = String(args[0]);
            const fs = require("fs");
            const path = require("path");
            const absolutePath = path.resolve(filePath);
            if (!fs.existsSync(absolutePath)) {
                throw new Error(\`Include file not found: \\\x27\${filePath}\\\x27\`);
            }
            const source = fs.readFileSync(absolutePath, "utf-8");
            const lexer = new (require("./lexer").Lexer)(source);
            const tokens = lexer.tokenize();
            const parser = new (require("./parser").Parser)(tokens);
            const statements = parser.parse();
            for (const statement of statements) {
                await this.execute(statement);
            }
            return null;
        }));
        this.globals.define("route", new BuiltinFunction(4, async (args) => {
            const method = String(args[0]);
            const path = String(args[1]);
            const action = String(args[2]);
            const name = String(args[3]);
            this.io.print(\`[Route Registered] \${method.toUpperCase()} \${path} -> \${action} (\${name})\\n\`);
            if (path === "/") {
                const parts = action.split("@");
                const actionName = parts[1];
                const controllerFunc = this.globals.get(actionName);
                if (controllerFunc && typeof controllerFunc.call === "function") {
                    const result = await controllerFunc.call(this, []);
                    this.io.print(\`[Route Executed] Result: \${result}\\n\`);
                } else {
                    this.io.print(\`[Route Error] Action \\\x27\${actionName}\\\x27 not found in global scope.\\n\`);
                }
            }
            return null;
        }));
    }`);
    fs.writeFileSync("dist/interpreter.js", content, "utf8");
}
'

node -e '
const fs = require("fs");
let appJs = fs.readFileSync("assets/app.js", "utf8");
appJs = appJs.replace("// Initialize Default Template", "if (editor) {\n// Initialize Default Template");
appJs = appJs.replace("// Inject spinner anim CSS", "}\n\n// Inject spinner anim CSS");
fs.writeFileSync("assets/app.js", appJs, "utf8");
'

node -e '
const fs = require("fs");
["style.css", "theme.css"].forEach(file => {
    let path = "assets/" + file;
    if (fs.existsSync(path)) {
        let code = fs.readFileSync(path, "utf8");
        code = code.replace(/\/\*[\s\S]*?\*\//g, "");
        fs.writeFileSync(path, code, "utf8");
    }
});
'

npm install --omit=dev
npm link
