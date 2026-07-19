#!/bin/bash
set -e

if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required to install AbiLang." >&2
    exit 1
fi

# Helper function to print to terminal
print_msg() {
    local msg="$1"
    if [ -t 1 ]; then
        echo "$msg"
    elif [ -c /dev/tty ] && : > /dev/tty 2>/dev/null; then
        echo "$msg" > /dev/tty
    else
        echo "$msg" >&2
    fi
}

# Helper function to prompt user for input (handles interactive and non-interactive cases)
prompt_user() {
    local prompt_msg="$1"
    local default_val="$2"
    local result_var="$3"
    local input_val
    
    if [ -t 0 ]; then
        printf "%s" "$prompt_msg"
        read -r input_val
    elif [ -c /dev/tty ] && : > /dev/tty 2>/dev/null; then
        printf "%s" "$prompt_msg" > /dev/tty
        read -r input_val < /dev/tty
    else
        printf "%s" "$prompt_msg" >&2
        if read -r input_val; then
            :
        else
            input_val=""
        fi
    fi
    
    if [ -z "$input_val" ]; then
        eval "$result_var=\"$default_val\""
    else
        eval "$result_var=\"$input_val\""
    fi
}

# 1. Ask for project name
prompt_user "Enter project name [my-abi-project]: " "my-abi-project" PROJECT_NAME

# Create and navigate to the project directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create folder structure
mkdir -p dist
mkdir -p assets
mkdir -p view
mkdir -p controller
mkdir -p model
mkdir -p routes

# 2. Ask if they want to configure environment variables (.env)
prompt_user "Do you want to configure environment variables (.env)? (y/n) [y]: " "y" CREATE_ENV

if [[ "$CREATE_ENV" =~ ^[Yy]$ ]]; then
    prompt_user "Enter PORT [3000]: " "3000" PORT
    
    prompt_user "Do you want to configure database details? (y/n) [y]: " "y" CONFIGURE_DB
    
    DATABASE_TYPE=""
    DATABASE_URL=""
    
    if [[ "$CONFIGURE_DB" =~ ^[Yy]$ ]]; then
        print_msg ""
        print_msg "Select Database Type:"
        print_msg "1) mysql"
        print_msg "2) postgres"
        print_msg "3) mongodb"
        print_msg "4) supabase"
        print_msg "5) sqlite"
        print_msg "6) sqlite3"
        
        prompt_user "Enter choice (1-6) [3]: " "3" DB_CHOICE
        
        case $DB_CHOICE in
            1)
                DATABASE_TYPE="mysql"
                prompt_user "Enter DB_HOST [localhost]: " "localhost" DB_HOST
                prompt_user "Enter DB_PORT [3306]: " "3306" DB_PORT
                prompt_user "Enter DB_DATABASE [proflujo_academy]: " "proflujo_academy" DB_DATABASE
                prompt_user "Enter DB_USERNAME [proflujo]: " "proflujo" DB_USERNAME
                prompt_user "Enter DB_PASSWORD [letmein1!]: " "letmein1!" DB_PASSWORD
                DEFAULT_URL="mysql://$DB_USERNAME:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_DATABASE"
                ;;
            2)
                DATABASE_TYPE="postgres"
                prompt_user "Enter DB_HOST [localhost]: " "localhost" DB_HOST
                prompt_user "Enter DB_PORT [5432]: " "5432" DB_PORT
                prompt_user "Enter DB_DATABASE [proflujo_academy]: " "proflujo_academy" DB_DATABASE
                prompt_user "Enter DB_USERNAME [proflujo]: " "proflujo" DB_USERNAME
                prompt_user "Enter DB_PASSWORD [letmein1!]: " "letmein1!" DB_PASSWORD
                DEFAULT_URL="postgres://$DB_USERNAME:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_DATABASE"
                ;;
            3)
                DATABASE_TYPE="mongodb"
                DEFAULT_URL="mongodb://localhost:27017/$PROJECT_NAME"
                ;;
            4)
                DATABASE_TYPE="supabase"
                DEFAULT_URL="postgresql://postgres:password@db.supabase.co:5432/postgres"
                ;;
            5)
                DATABASE_TYPE="sqlite"
                DEFAULT_URL="sqlite://database.db"
                ;;
            6)
                DATABASE_TYPE="sqlite3"
                DEFAULT_URL="sqlite3://database.db"
                ;;
            *)
                DATABASE_TYPE="mongodb"
                DEFAULT_URL="mongodb://localhost:27017/$PROJECT_NAME"
                ;;
        esac
        
        if [ "$DATABASE_TYPE" != "postgres" ] && [ "$DATABASE_TYPE" != "mysql" ]; then
            prompt_user "Enter DATABASE_URL [$DEFAULT_URL]: " "$DEFAULT_URL" DATABASE_URL
        fi
    fi
    
    prompt_user "Enter API_KEY [xyz123secret]: " "xyz123secret" API_KEY
    
    # Generate default uppercase APP_NAME matching project name
    APP_NAME=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]')
    
    # Write .env file
    {
        echo "PORT=$PORT"
        echo "APP_NAME=$APP_NAME"
        if [ "$DATABASE_TYPE" = "postgres" ]; then
            echo "DB_CONNECTION=pgsql"
            echo "DB_HOST=$DB_HOST"
            echo "DB_PORT=$DB_PORT"
            echo "DB_DATABASE=$DB_DATABASE"
            echo "DB_USERNAME=$DB_USERNAME"
            echo "DB_PASSWORD=$DB_PASSWORD"
        elif [ "$DATABASE_TYPE" = "mysql" ]; then
            echo "DB_CONNECTION=mysql"
            echo "DB_HOST=$DB_HOST"
            echo "DB_PORT=$DB_PORT"
            echo "DB_DATABASE=$DB_DATABASE"
            echo "DB_USERNAME=$DB_USERNAME"
            echo "DB_PASSWORD=$DB_PASSWORD"
        elif [ -n "$DATABASE_TYPE" ]; then
            echo "DATABASE_TYPE=\"$DATABASE_TYPE\""
            echo "DATABASE_URL=\"$DATABASE_URL\""
        fi
        echo "API_KEY=$API_KEY"
    } > .env
    
    if [ -c /dev/tty ]; then
        echo ".env file created successfully!" > /dev/tty
    else
        echo ".env file created successfully!"
    fi
fi

# Base repository URL
BASE_URL="https://raw.githubusercontent.com/abinashmofficial/abilang/master-v1"

# 3. Create package.json
cat << EOF > package.json
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "The Progressive Scripting Language Project",
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

# 4. Download source binary components
for file in cli.js index.js interpreter.js lexer.js parser.js types.js; do
    curl -fsSL "$BASE_URL/dist/$file" -o "dist/$file"
done

# 5. Download the complete web index.html and update asset paths for view/index.html
curl -fsSL "$BASE_URL/web/index.html" -o view/index.html
node -e '
const fs = require("fs");
let html = fs.readFileSync("view/index.html", "utf8");
html = html.replace("href=\"theme.css?v=1.2\"", "href=\"../assets/theme.css?v=1.2\"");
html = html.replace("href=\"style.css?v=1.2\"", "href=\"../assets/style.css?v=1.2\"");
html = html.replace("src=\"dist/abilang.min.js?v=1.2\"", "src=\"../assets/abilang.min.js?v=1.2\"");
html = html.replace("src=\"app.js?v=1.2\"", "src=\"../assets/app.js?v=1.2\"");
fs.writeFileSync("view/index.html", html, "utf8");
'

# 6. Create custom server.js supporting .env configuration
cat << 'EOF' > server.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { Interpreter, BuiltinFunction } = require('./dist/interpreter');
const { Lexer } = require('./dist/lexer');
const { Parser } = require('./dist/parser');

// Load environment variables from .env file if it exists
const envFile = path.resolve('.env');
if (fs.existsSync(envFile)) {
    const envContent = fs.readFileSync(envFile, 'utf8');
    envContent.split(/\r?\n/).forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
            const parts = trimmed.split('=');
            if (parts.length >= 2) {
                const key = parts[0].trim();
                let val = parts.slice(1).join('=').trim();
                if ((val.startsWith("\"") && val.endsWith("\"")) || (val.startsWith("\x27") && val.endsWith("\x27"))) {
                    val = val.substring(1, val.length - 1);
                }
                process.env[key] = val;
            }
        }
    });
}

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

    const PORT = process.env.PORT || 8080;
    server.listen(PORT, '127.0.0.1', () => {
        console.log(`Server running at http://127.0.0.1:${PORT}/`);
    });
}

startServer().catch(err => {
    console.error(err);
    process.exit(1);
});
EOF

# 7. Create routing components
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

# 8. Download design assets (CSS, JS, layout etc.)
curl -fsSL "$BASE_URL/web/app.js" -o assets/app.js
curl -fsSL "$BASE_URL/web/style.css" -o assets/style.css
curl -fsSL "$BASE_URL/web/theme.css" -o assets/theme.css
curl -fsSL "$BASE_URL/web/dist/abilang.min.js" -o assets/abilang.min.js

# 9. Configure global executables
echo '#!/usr/bin/env node' | cat - dist/cli.js > temp && mv temp dist/cli.js
chmod +x dist/cli.js

# Modify interpreter.js components to include standard route/include registration
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

# Patch app.js: 
# 1) Make safe fallback if editor element is missing
# 2) Fix regular expression syntax error (unterminated group) to allow light theme to work
node -e '
const fs = require("fs");
let appJs = fs.readFileSync("assets/app.js", "utf8");
appJs = appJs.replace("// Initialize Default Template", "if (editor) {\n// Initialize Default Template");
appJs = appJs.replace("// Inject spinner anim CSS", "}\n\n// Inject spinner anim CSS");
// Correct the malformed regex syntax error
appJs = appJs.replace("(\\b[a-zA-Z_][a-zA-Z0-9_]*\\b(?=\\s*\\(()", "(\\b[a-zA-Z_][a-zA-Z0-9_]*\\b(?=\\s*\\())");
fs.writeFileSync("assets/app.js", appJs, "utf8");
'

# Mini-minify styling files
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

# Complete dependency link
npm install --omit=dev
npm link

echo ""
echo "============================================="
echo "AbiLang Project successfully created!"
echo "Project Path: $(pwd)"
echo "To start the web server, run:"
echo "  npm run web"
echo "============================================="
