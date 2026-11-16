import { dispatch } from '../../_lib/khatma-api.js';

// /api/khatma/* (specs/014 contracts/group-api.md).
export const onRequest = ({ request, env }) => dispatch(request, env);
