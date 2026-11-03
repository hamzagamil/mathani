import { dispatch } from '../../_lib/editor-api.js';
export const onRequest = ({ request, env }) => dispatch(request, env);
