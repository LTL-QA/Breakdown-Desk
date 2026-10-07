import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({base:'./',plugins:[react()],define:{'process.env.NODE_ENV':JSON.stringify('production')},build:{lib:{entry:'src/main.tsx',name:'BreakdownDesk',formats:['iife'],fileName:()=> 'app.js'},minify:true,emptyOutDir:true}});
